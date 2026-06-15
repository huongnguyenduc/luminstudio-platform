package processing

import (
	"context"
	"encoding/json"
	"errors"
	"strings"
	"testing"
	"time"

	"lumin.studio/services/api-gateway/internal/product"
)

type completerStub struct {
	id        string
	optimized product.ObjectRef
	sprite    product.ObjectRef
	now       time.Time
	err       error
	calls     int
}

func (stub *completerStub) CompleteProcessing(_ context.Context, id string, optimized, sprite product.ObjectRef, now time.Time) (product.ProductRecord, error) {
	stub.calls++
	stub.id, stub.optimized, stub.sprite, stub.now = id, optimized, sprite, now
	return product.ProductRecord{}, stub.err
}

func TestHandleTaskCompletedUpdatesProduct(t *testing.T) {
	now := time.Date(2026, 6, 15, 16, 0, 0, 0, time.UTC)
	completer := &completerStub{}
	data := completionJSON(t, now)

	if err := NewCompletionHandler(completer).HandleTaskCompleted(context.Background(), data); err != nil {
		t.Fatalf("handle completion: %v", err)
	}
	if completer.calls != 1 || completer.id != "prod_12345678" || completer.now != now {
		t.Fatalf("unexpected completion call: %#v", completer)
	}
	if completer.optimized.Bucket != "lumin-optimized-glb" || completer.sprite.Bucket != "lumin-360-sprites" {
		t.Fatalf("unexpected processed assets: %#v", completer)
	}
}

func TestHandleTaskCompletedRejectsUnknownFields(t *testing.T) {
	data := append(completionJSON(t, time.Now()), []byte(` {}`)...)
	if err := NewCompletionHandler(&completerStub{}).HandleTaskCompleted(context.Background(), data); err == nil {
		t.Fatal("multiple JSON objects must fail")
	}
}

func TestHandleTaskCompletedRejectsWrongAssetBucket(t *testing.T) {
	now := time.Now()
	event := validCompletionEvent(now)
	event.Payload.OptimizedAsset.Bucket = "lumin-source-glb"
	data, _ := json.Marshal(event)
	if err := NewCompletionHandler(&completerStub{}).HandleTaskCompleted(context.Background(), data); err == nil {
		t.Fatal("wrong optimized bucket must fail")
	}
}

func TestHandleTaskCompletedPropagatesStoreFailure(t *testing.T) {
	completer := &completerStub{err: errors.New("database unavailable")}
	err := NewCompletionHandler(completer).HandleTaskCompleted(context.Background(), completionJSON(t, time.Now()))
	if err == nil || !strings.Contains(err.Error(), "complete product processing") {
		t.Fatalf("error = %v", err)
	}
}

func completionJSON(t *testing.T, now time.Time) []byte {
	t.Helper()
	data, err := json.Marshal(validCompletionEvent(now))
	if err != nil {
		t.Fatalf("marshal completion event: %v", err)
	}
	return data
}

func validCompletionEvent(now time.Time) product.TaskCompletedEvent {
	return product.TaskCompletedEvent{
		ID: "evt_12345678", Type: "3d.task.completed", SchemaVersion: "v1",
		OccurredAt: now, CorrelationID: "corr_12345678",
		Payload: product.TaskCompletedPayload{
			TaskID: "task_12345678", ProductID: "prod_12345678",
			OptimizedAsset: product.ObjectRef{Bucket: "lumin-optimized-glb", Key: "prod_12345678_low.glb"},
			SpriteAsset:    product.ObjectRef{Bucket: "lumin-360-sprites", Key: "prod_12345678_360_sprite.jpg"},
		},
	}
}
