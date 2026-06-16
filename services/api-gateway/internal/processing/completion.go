package processing

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net"
	"net/url"
	"strconv"
	"strings"
	"time"

	"lumin.studio/services/api-gateway/internal/product"
)

const (
	natsQueueGroup = "processing-completion"
	natsSID        = "2"
	natsConnect    = "CONNECT {\"verbose\":false,\"pedantic\":true,\"lang\":\"go\",\"version\":\"lumin-api-gateway\"}\r\n"
)

type ProductCompleter interface {
	CompleteProcessing(ctx context.Context, id string, optimizedAsset, spriteAsset product.ObjectRef, now time.Time) (product.ProductRecord, error)
}

type CompletionHandler struct {
	products       ProductCompleter
	eventPublisher product.EventPublisher
}

func NewCompletionHandler(products ProductCompleter) CompletionHandler {
	return CompletionHandler{products: products}
}

func (handler CompletionHandler) WithEventPublisher(publisher product.EventPublisher) CompletionHandler {
	handler.eventPublisher = publisher
	return handler
}

func (handler CompletionHandler) HandleTaskCompleted(ctx context.Context, data []byte) error {
	if handler.products == nil {
		return errors.New("product completer is not configured")
	}
	var event product.TaskCompletedEvent
	decoder := json.NewDecoder(bytes.NewReader(data))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&event); err != nil {
		return fmt.Errorf("decode 3d.task.completed event: %w", err)
	}
	if err := decoder.Decode(&struct{}{}); err != io.EOF {
		return errors.New("3d.task.completed event must contain one JSON object")
	}
	if err := event.Validate(); err != nil {
		return err
	}
	record, err := handler.products.CompleteProcessing(
		ctx,
		event.Payload.ProductID,
		event.Payload.OptimizedAsset,
		event.Payload.SpriteAsset,
		event.OccurredAt,
	)
	if err != nil {
		return fmt.Errorf("complete product processing: %w", err)
	}
	if handler.eventPublisher != nil {
		updatedEvent, err := product.NewProductUpdatedEvent(event.ID+"-product-updated", event.CorrelationID, record)
		if err != nil {
			return fmt.Errorf("build completion product.updated event: %w", err)
		}
		if err := handler.eventPublisher.PublishProductUpdated(ctx, updatedEvent); err != nil {
			return fmt.Errorf("publish completion product.updated event: %w", err)
		}
	}
	return nil
}

type EventHandler interface {
	HandleTaskCompleted(ctx context.Context, data []byte) error
}

type NATSSubscriber struct {
	natsURL       *url.URL
	timeout       time.Duration
	retryInterval time.Duration
	handler       EventHandler
}

func NewNATSSubscriber(natsURL *url.URL, timeout time.Duration, handler EventHandler) NATSSubscriber {
	return NATSSubscriber{natsURL: natsURL, timeout: timeout, retryInterval: timeout, handler: handler}
}

func (subscriber NATSSubscriber) Run(ctx context.Context) error {
	if subscriber.natsURL == nil || subscriber.natsURL.Host == "" {
		return errors.New("NATS URL is not configured")
	}
	if subscriber.handler == nil {
		return errors.New("event handler is not configured")
	}
	if subscriber.retryInterval <= 0 {
		subscriber.retryInterval = time.Second
	}
	for {
		if err := subscriber.runOnce(ctx); err != nil && ctx.Err() == nil {
			slog.Error("processing completion subscriber disconnected", "error", err)
		}
		if ctx.Err() != nil {
			return ctx.Err()
		}
		timer := time.NewTimer(subscriber.retryInterval)
		select {
		case <-ctx.Done():
			timer.Stop()
			return ctx.Err()
		case <-timer.C:
		}
	}
}

func (subscriber NATSSubscriber) runOnce(ctx context.Context) error {
	connection, err := (&net.Dialer{}).DialContext(ctx, "tcp", subscriber.natsURL.Host)
	if err != nil {
		return fmt.Errorf("connect to NATS: %w", err)
	}
	defer connection.Close()
	if subscriber.timeout > 0 {
		_ = connection.SetDeadline(time.Now().Add(subscriber.timeout))
	}
	reader := &natsReader{source: connection}
	line, err := reader.readLine()
	if err != nil {
		return fmt.Errorf("read NATS greeting: %w", err)
	}
	if !strings.HasPrefix(line, "INFO ") {
		return errors.New("unexpected NATS greeting")
	}
	if _, err := fmt.Fprintf(connection, "%sSUB %s %s %s\r\nPING\r\n", natsConnect, product.ProcessingTaskCompletedSubject, natsQueueGroup, natsSID); err != nil {
		return fmt.Errorf("subscribe to 3d.task.completed: %w", err)
	}
	for {
		line, err := reader.readLine()
		if err != nil {
			return err
		}
		fields := strings.Fields(line)
		if len(fields) == 0 {
			continue
		}
		switch fields[0] {
		case "PING":
			if _, err := connection.Write([]byte("PONG\r\n")); err != nil {
				return err
			}
		case "PONG":
			if subscriber.timeout > 0 {
				_ = connection.SetDeadline(time.Time{})
			}
		case "MSG":
			payload, err := reader.readMessage(fields)
			if err != nil {
				return err
			}
			if err := subscriber.handler.HandleTaskCompleted(ctx, payload); err != nil {
				slog.Error("processing completion failed", "error", err)
			}
		case "-ERR":
			return fmt.Errorf("NATS error: %s", line)
		}
	}
}

type natsReader struct {
	source io.Reader
}

func (reader *natsReader) readLine() (string, error) {
	var builder strings.Builder
	var one [1]byte
	for {
		n, err := reader.source.Read(one[:])
		if n > 0 {
			builder.WriteByte(one[0])
			if strings.HasSuffix(builder.String(), "\r\n") {
				return strings.TrimSuffix(builder.String(), "\r\n"), nil
			}
		}
		if err != nil {
			return "", err
		}
	}
}

func (reader *natsReader) readMessage(fields []string) ([]byte, error) {
	if len(fields) < 4 {
		return nil, errors.New("malformed NATS MSG line")
	}
	size, err := strconv.Atoi(fields[len(fields)-1])
	if err != nil || size < 0 {
		return nil, errors.New("malformed NATS MSG size")
	}
	payload := make([]byte, size+2)
	if _, err := io.ReadFull(reader.source, payload); err != nil {
		return nil, err
	}
	if string(payload[size:]) != "\r\n" {
		return nil, errors.New("malformed NATS MSG payload terminator")
	}
	return payload[:size], nil
}
