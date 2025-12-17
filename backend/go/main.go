package main

import (
	"database/sql"
	"encoding/json"
	"log"
	"net/http"
	"time"

	_ "github.com/mattn/go-sqlite3"
)

type Link struct {
	ID        int       `json:"id"`
	ShortCode string    `json:"short_code"`
	LongURL   string    `json:"long_url"`
	Clicks    int       `json:"clicks"`
	CreatedAt time.Time `json:"created_at"`
}

var db *sql.DB

func main() {
	var err error
	db, err = sql.Open("sqlite3", "./rayphoenix.db")
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()

	// Create tables if they don't exist
	createTables()

	http.HandleFunc("/", handleRedirect)
	http.HandleFunc("/api/links", handleLinks)
	http.HandleFunc("/api/links/", handleLinkDetail)
	http.HandleFunc("/health", handleHealth)

	log.Println("Rayphoenix redirect service running on :8080")
	log.Fatal(http.ListenAndServe(":8080", enableCORS(http.DefaultServeMux)))
}

func createTables() {
	query := `
	CREATE TABLE IF NOT EXISTS links (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		short_code TEXT UNIQUE NOT NULL,
		long_url TEXT NOT NULL,
		clicks INTEGER DEFAULT 0,
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP
	);
	CREATE INDEX IF NOT EXISTS idx_short_code ON links(short_code);
	`
	_, err := db.Exec(query)
	if err != nil {
		log.Fatal(err)
	}
}

func handleRedirect(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path == "/" {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("Rayphoenix URL Shortener"))
		return
	}

	shortCode := r.URL.Path[1:]

	var longURL string
	err := db.QueryRow("SELECT long_url FROM links WHERE short_code = ?", shortCode).Scan(&longURL)

	if err == sql.ErrNoRows {
		http.Error(w, "Short link not found", http.StatusNotFound)
		return
	}
	if err != nil {
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	// Increment click count
	_, err = db.Exec("UPDATE links SET clicks = clicks + 1 WHERE short_code = ?", shortCode)
	if err != nil {
		log.Printf("Error updating clicks: %v", err)
	}

	http.Redirect(w, r, longURL, http.StatusFound)
}

func handleLinks(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case "GET":
		getLinks(w, r)
	case "POST":
		createLink(w, r)
	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

func getLinks(w http.ResponseWriter, r *http.Request) {
	rows, err := db.Query("SELECT id, short_code, long_url, clicks, created_at FROM links ORDER BY created_at DESC")
	if err != nil {
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var links []Link
	for rows.Next() {
		var link Link
		err := rows.Scan(&link.ID, &link.ShortCode, &link.LongURL, &link.Clicks, &link.CreatedAt)
		if err != nil {
			continue
		}
		links = append(links, link)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(links)
}

func createLink(w http.ResponseWriter, r *http.Request) {
	var link Link
	err := json.NewDecoder(r.Body).Decode(&link)
	if err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	if link.ShortCode == "" || link.LongURL == "" {
		http.Error(w, "short_code and long_url are required", http.StatusBadRequest)
		return
	}

	result, err := db.Exec("INSERT INTO links (short_code, long_url) VALUES (?, ?)",
		link.ShortCode, link.LongURL)
	if err != nil {
		http.Error(w, "Short code already exists or database error", http.StatusConflict)
		return
	}

	id, _ := result.LastInsertId()
	link.ID = int(id)
	link.Clicks = 0
	link.CreatedAt = time.Now()

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(link)
}

func handleLinkDetail(w http.ResponseWriter, r *http.Request) {
	shortCode := r.URL.Path[len("/api/links/"):]

	if r.Method == "DELETE" {
		_, err := db.Exec("DELETE FROM links WHERE short_code = ?", shortCode)
		if err != nil {
			http.Error(w, "Internal server error", http.StatusInternalServerError)
			return
		}
		w.WriteHeader(http.StatusNoContent)
		return
	}

	http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
}

func handleHealth(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("OK"))
}

func enableCORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		next.ServeHTTP(w, r)
	})
}
