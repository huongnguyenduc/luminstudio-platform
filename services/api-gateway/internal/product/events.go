package product

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"net/url"
	"strings"
	"time"
)

const (
	productUpdatedEventType = "product.updated"
	taskCreatedEventType    = "3d.task.created"
	eventSchemaVersion      = "v1"
	productUpdatedSubject   = "lumin.product.updated"
	taskCreatedSubject      = "lumin.3d.task.created"
	correlationIDHeader     = "X-Correlation-ID"
)

const ProductUpdatedSubject = productUpdatedSubject
const ProcessingTaskCreatedSubject = taskCreatedSubject

var errInvalidCorrelationID = errors.New("correlation id must match the v1 correlation id contract")

type EventPublisher interface {
	PublishProductUpdated(ctx context.Context, event ProductUpdatedEvent) error
	PublishProcessingTaskCreated(ctx context.Context, event TaskCreatedEvent) error
}

type ProductUpdatedEvent struct {
	ID            string                `json:"id"`
	Type          string                `json:"type"`
	SchemaVersion string                `json:"schemaVersion"`
	OccurredAt    time.Time             `json:"occurredAt"`
	CorrelationID string                `json:"correlationId"`
	Payload       ProductUpdatedPayload `json:"payload"`
}

type ProductUpdatedPayload struct {
	ProductID string    `json:"productId"`
	ChangedAt time.Time `json:"changedAt"`
}

type TaskCreatedEvent struct {
	ID            string             `json:"id"`
	Type          string             `json:"type"`
	SchemaVersion string             `json:"schemaVersion"`
	OccurredAt    time.Time          `json:"occurredAt"`
	CorrelationID string             `json:"correlationId"`
	Payload       TaskCreatedPayload `json:"payload"`
}

type TaskCreatedPayload struct {
	TaskID          string          `json:"taskId"`
	ProductID       string          `json:"productId"`
	SourceAsset     ObjectRef       `json:"sourceAsset"`
	MeshColorConfig MeshColorConfig `json:"meshColorConfig"`
}

func NewProductUpdatedEvent(eventID, correlationID string, record ProductRecord) (ProductUpdatedEvent, error) {
	if !validEventID(eventID) {
		return ProductUpdatedEvent{}, errors.New("event id must match the v1 event id contract")
	}
	if !validCorrelationID(correlationID) {
		return ProductUpdatedEvent{}, errInvalidCorrelationID
	}
	if !productIDPattern.MatchString(record.ID) {
		return ProductUpdatedEvent{}, errors.New("product id must match the v1 product id contract")
	}
	if record.UpdatedAt.IsZero() {
		return ProductUpdatedEvent{}, errors.New("updatedAt is required for product.updated")
	}
	return ProductUpdatedEvent{
		ID:            eventID,
		Type:          productUpdatedEventType,
		SchemaVersion: eventSchemaVersion,
		OccurredAt:    record.UpdatedAt,
		CorrelationID: correlationID,
		Payload: ProductUpdatedPayload{
			ProductID: record.ID,
			ChangedAt: record.UpdatedAt,
		},
	}, nil
}

func NewTaskCreatedEvent(eventID, correlationID, taskID string, record ProductRecord) (TaskCreatedEvent, error) {
	if !validEventID(eventID) {
		return TaskCreatedEvent{}, errors.New("event id must match the v1 event id contract")
	}
	if !validCorrelationID(correlationID) {
		return TaskCreatedEvent{}, errInvalidCorrelationID
	}
	if !taskIDPattern.MatchString(taskID) {
		return TaskCreatedEvent{}, errors.New("task id must match the v1 processing task id contract")
	}
	if !productIDPattern.MatchString(record.ID) {
		return TaskCreatedEvent{}, errors.New("product id must match the v1 product id contract")
	}
	if record.SourceAsset == nil {
		return TaskCreatedEvent{}, errors.New("sourceAsset is required for 3d.task.created")
	}
	if err := record.SourceAsset.validate(); err != nil {
		return TaskCreatedEvent{}, fmt.Errorf("sourceAsset: %w", err)
	}
	if record.MeshColorConfig == nil {
		return TaskCreatedEvent{}, errors.New("meshColorConfig is required for 3d.task.created")
	}
	if err := record.MeshColorConfig.validate(); err != nil {
		return TaskCreatedEvent{}, err
	}
	if record.UpdatedAt.IsZero() {
		return TaskCreatedEvent{}, errors.New("updatedAt is required for 3d.task.created")
	}
	return TaskCreatedEvent{
		ID:            eventID,
		Type:          taskCreatedEventType,
		SchemaVersion: eventSchemaVersion,
		OccurredAt:    record.UpdatedAt,
		CorrelationID: correlationID,
		Payload: TaskCreatedPayload{
			TaskID:          taskID,
			ProductID:       record.ID,
			SourceAsset:     *record.SourceAsset,
			MeshColorConfig: record.MeshColorConfig,
		},
	}, nil
}

type NATSPublisher struct {
	url     *url.URL
	timeout time.Duration
}

func NewNATSPublisher(natsURL *url.URL, timeout time.Duration) NATSPublisher {
	return NATSPublisher{
		url:     natsURL,
		timeout: timeout,
	}
}

func (publisher NATSPublisher) PublishProductUpdated(ctx context.Context, event ProductUpdatedEvent) error {
	return publisher.publish(ctx, productUpdatedSubject, event, "product.updated")
}

func (publisher NATSPublisher) PublishProcessingTaskCreated(ctx context.Context, event TaskCreatedEvent) error {
	return publisher.publish(ctx, taskCreatedSubject, event, "3d.task.created")
}

func (publisher NATSPublisher) publish(ctx context.Context, subject string, event any, eventName string) error {
	if publisher.url == nil || publisher.url.Host == "" {
		return errors.New("NATS URL is not configured")
	}
	if subject == "" || strings.ContainsAny(subject, " \t\r\n") {
		return errors.New("NATS subject is invalid")
	}
	payload, err := json.Marshal(event)
	if err != nil {
		return fmt.Errorf("marshal %s event: %w", eventName, err)
	}
	ctx, cancel := context.WithTimeout(ctx, publisher.timeout)
	defer cancel()

	dialer := net.Dialer{}
	connection, err := dialer.DialContext(ctx, "tcp", publisher.url.Host)
	if err != nil {
		return fmt.Errorf("connect to NATS: %w", err)
	}
	defer connection.Close()
	if deadline, ok := ctx.Deadline(); ok {
		_ = connection.SetDeadline(deadline)
	}

	reader := bufio.NewReader(connection)
	line, err := reader.ReadString('\n')
	if err != nil {
		return fmt.Errorf("read NATS greeting: %w", err)
	}
	if !strings.HasPrefix(line, "INFO ") {
		return errors.New("unexpected NATS greeting")
	}
	if _, err := fmt.Fprintf(connection, "PUB %s %d\r\n%s\r\nPING\r\n", subject, len(payload), payload); err != nil {
		return fmt.Errorf("publish %s event: %w", eventName, err)
	}
	line, err = reader.ReadString('\n')
	if err != nil {
		return fmt.Errorf("read NATS publish acknowledgement: %w", err)
	}
	if strings.TrimSpace(line) != "PONG" {
		return errors.New("unexpected NATS publish acknowledgement")
	}
	return nil
}

func validEventID(value string) bool {
	return len(value) >= 8 && len(value) <= 128 && strings.TrimSpace(value) == value
}

func validCorrelationID(value string) bool {
	return len(value) >= 8 && len(value) <= 128 && strings.TrimSpace(value) == value
}
