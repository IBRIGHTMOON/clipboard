package main

/*
#cgo LDFLAGS: -framework Cocoa -framework ApplicationServices -framework Carbon
#include "bridge.h"
*/
import "C"

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"unsafe"
)

const maxEntries = 100

type historyStore struct {
	mu      sync.RWMutex
	entries []string
	path    string
}

var history = newHistory()

func newHistory() *historyStore {
	dir, err := os.UserConfigDir()
	if err != nil {
		dir = "."
	}
	h := &historyStore{path: filepath.Join(dir, "ClipboardHistory", "history.json")}
	data, err := os.ReadFile(h.path)
	if err == nil {
		_ = json.Unmarshal(data, &h.entries)
	}
	return h
}

func (h *historyStore) add(text string) {
	text = strings.TrimSpace(text)
	if text == "" {
		return
	}
	h.mu.Lock()
	defer h.mu.Unlock()
	filtered := make([]string, 0, len(h.entries)+1)
	filtered = append(filtered, text)
	for _, item := range h.entries {
		if item != text {
			filtered = append(filtered, item)
		}
		if len(filtered) == maxEntries {
			break
		}
	}
	h.entries = filtered
	h.saveLocked()
}

func (h *historyStore) saveLocked() {
	data, err := json.Marshal(h.entries)
	if err != nil {
		return
	}
	if os.MkdirAll(filepath.Dir(h.path), 0o755) == nil {
		_ = os.WriteFile(h.path, data, 0o600)
	}
}

func (h *historyStore) all() []string {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return append([]string(nil), h.entries...)
}

//export GoClipboardChanged
func GoClipboardChanged(text *C.char) {
	if text != nil {
		history.add(C.GoString(text))
	}
}

//export GoHistoryJSON
func GoHistoryJSON() *C.char {
	data, _ := json.Marshal(history.all())
	return C.CString(string(data))
}

//export GoSelectHistory
func GoSelectHistory(index C.int) {
	items := history.all()
	i := int(index)
	if i >= 0 && i < len(items) {
		value := C.CString(items[i])
		C.WriteClipboard(value)
		C.free(unsafe.Pointer(value))
		history.add(items[i])
	}
}

func main() {
	C.RunClipboardApp()
}
