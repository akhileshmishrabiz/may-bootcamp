# Use the official Go image based on Alpine Linux
FROM golang:1.20.10-alpine3.18

# Set the working directory inside the container
WORKDIR /app

# Copy go mod files first for better caching
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy the rest of the application code
COPY . .

# Build the Go application
RUN go build -o app

# Expose port 8080 for the application
EXPOSE 8080

# Define the command to run the Go application
CMD ["./app"]
