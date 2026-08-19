# --- ETAPA 1: Compilación con compilador oficial más reciente ---
FROM golang:alpine AS builder

WORKDIR /src

# Copiar dependencias y hashes de verificación
COPY go.mod go.sum ./
RUN go mod download

# Copiar código fuente
COPY . .

# Compilación estática pura (sin CGO, con stripping de símbolos y sin rutas de host)
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-w -s" -o /src/api-server main.go

# --- ETAPA 2: Runtime Seguro Distroless (Zero-Shell) ---
FROM gcr.io/distroless/static-debian12:nonroot

WORKDIR /

# Copiar exclusivamente el binario compilado asignando propiedad a nonroot
COPY --from=builder --chown=nonroot:nonroot /src/api-server /api-server

# Ejecutar bajo usuario no privilegiado (UID 65532)
USER nonroot:nonroot

EXPOSE 8080

ENTRYPOINT ["/api-server"]
