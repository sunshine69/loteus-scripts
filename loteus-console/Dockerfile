# --- STAGE 1: Build Environment ---
FROM golang:1.26.3-alpine3.23 AS builder

# 1. Install all standard development tools, musl, and graphics dev files
RUN apk add --no-cache \
    build-base \
    g++ \
    git \
    musl-dev \
    wayland-dev \
    mesa-dev \
    libx11-dev \
    libxft-dev \
    libxext-dev \
    libxinerama-dev \
    libxcursor-dev \
    libxfixes-dev \
    libdecor-dev \
    pango-dev \
    cairo-dev

WORKDIR /app

# 2. Copy your Go code module files over
COPY go.mod go.sum ./
RUN go mod download

# 3. CRITICAL: Pull the go-fltk source to manually run 'go generate'
# This forces FLTK to recompile its C++ code directly against Alpine's static musl environment.
RUN go get github.com/pwiecz/go-fltk && \
    cd $(go env GOPATH)/pkg/mod/github.com/pwiecz/go-fltk* && \
    CGO_ENABLED=1 go generate

# 4. Copy the rest of your app and compile with strict static link flags
COPY . .
RUN CGO_ENABLED=1 go build \
    -tags netgo \
    -ldflags '-linkmode external -extldflags "-static"' \
    -o my-fltk-app .

# --- STAGE 2: Deployment Bin Output ---
# You can leave this final stage completely empty or use scratch. 
# This proves your binary is truly 100% static and requires zero runtime files.
FROM scratch
COPY --from=builder /app/my-fltk-app /my-fltk-app
ENTRYPOINT ["/my-fltk-app"]

