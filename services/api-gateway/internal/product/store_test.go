package product

import (
	"encoding/json"
	"testing"
	"time"
)

func TestNewInsertProductArgsEncodesValidatedDraft(t *testing.T) {
	now := time.Date(2026, 6, 15, 12, 0, 0, 0, time.UTC)
	args, err := NewInsertProductArgs("prod_12345678", validDraft(), now)
	if err != nil {
		t.Fatalf("building insert args failed: %v", err)
	}
	if args.ProcessingStatus != ProcessingNotStarted {
		t.Fatalf("processing status = %q, want %q", args.ProcessingStatus, ProcessingNotStarted)
	}
	var sections []InformationSection
	if err := json.Unmarshal(args.InformationSections, &sections); err != nil {
		t.Fatalf("information sections were not JSON: %v", err)
	}
	if len(sections) != 1 || sections[0].Title != "Materials" {
		t.Fatalf("unexpected information sections: %#v", sections)
	}
	var meshConfig MeshColorConfig
	if err := json.Unmarshal(args.MeshColorConfig, &meshConfig); err != nil {
		t.Fatalf("mesh config was not JSON: %v", err)
	}
	if meshConfig["mesh_body"].Default != "#FFFFFF" {
		t.Fatalf("unexpected mesh config: %#v", meshConfig)
	}
	var source ObjectRef
	if err := json.Unmarshal(args.SourceAsset, &source); err != nil {
		t.Fatalf("source asset was not JSON: %v", err)
	}
	if source.Bucket != "lumin-source-glb" {
		t.Fatalf("source bucket = %q", source.Bucket)
	}
}

func TestNewInsertProductArgsRejectsInvalidID(t *testing.T) {
	_, err := NewInsertProductArgs("bad", validDraft(), time.Now())
	if err == nil {
		t.Fatal("expected invalid id to be rejected")
	}
}
