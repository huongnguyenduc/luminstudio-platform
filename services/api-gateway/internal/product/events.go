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
	eventSchemaVersion      = "v1"
	productUpdatedSubject   = "lumin.product.updated"
	correlationIDHeader     = "X-Correlation-ID"
)

const ProductUpdatedSubject = productUpdatedSubject

var errInvalidCorrelationID = errors.New("correlation id must match the v1 correlation id contract")

type EventPublisher interface {
	PublishProductUpdated(ctx context.Context, event ProductUpdatedEvent) error
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

type NATSPublisher struct {
	url     *url.URL
	subject string
	timeout time.Duration
}

func NewNATSPublisher(natsURL *url.URL, timeout time.Duration) NATSPublisher {
	return NATSPublisher{
		url:     natsURL,
		subject: productUpdatedSubject,
		timeout: timeout,
	}
}

func (publisher NATSPublisher) PublishProductUpdated(ctx context.Context, event ProductUpdatedEvent) error {
	if publisher.url == nil || publisher.url.Host == "" {
		return errors.New("NATS URL is not configured")
	}
	if publisher.subject == "" || strings.ContainsAny(publisher.subject, " \t\r\n") {
		return errors.New("NATS subject is invalid")
	}
	payload, err := json.Marshal(event)
	if err != nil {
		return fmt.Errorf("marshal product.updated event: %w", err)
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
	if _, err := fmt.Fprintf(connection, "PUB %s %d\r\n%s\r\nPING\r\n", publisher.subject, len(payload), payload); err != nil {
		return fmt.Errorf("publish product.updated event: %w", err)
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
