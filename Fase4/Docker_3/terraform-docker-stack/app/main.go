package main

import (
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	_ "github.com/lib/pq"
)

func handler(w http.ResponseWriter, r *http.Request) {
	dbHost := os.Getenv("DB_HOST")
	dbUser := os.Getenv("DB_USER")
	dbPass := os.Getenv("DB_PASSWORD")
	dbName := os.Getenv("DB_NAME")

	dsn := fmt.Sprintf("host=%s port=5432 user=%s password=%s dbname=%s sslmode=disable", dbHost, dbUser, dbPass, dbName)
	db, err := sql.Open("postgres", dsn)
	if err != nil {
		http.Error(w, fmt.Sprintf("Error al conectar a PostgreSQL: %s", err), 500)
		return
	}
	defer db.Close()

	var dbTime string
	err = db.QueryRow("SELECT NOW()::text;").Scan(&dbTime)
	if err != nil {
		http.Error(w, fmt.Sprintf("Error al consultar PostgreSQL: %s", err), 500)
		return
	}

	hostname, _ := os.Hostname()
	fmt.Fprintf(w, "=== SRE MASTERCLASS: RESPUESTA MULTI-TIER ===\n")
	fmt.Fprintf(w, "Host Contenedor API: %s\n", hostname)
	fmt.Fprintf(w, "Fecha/Hora Base de Datos: %s\n", dbTime)
	fmt.Fprintf(w, "Estado: Conexión inter-contenedor validada exitosamente vía DNS interno.\n")
}

func main() {
	http.HandleFunc("/api", handler)
	log.Println("Microservicio API iniciado en puerto 8080...")
	server := &http.Server{
		Addr:         ":8080",
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
	}
	log.Fatal(server.ListenAndServe())
}
