package main

import (
	"github.com/gin-gonic/gin"
	"recommendation/api"
	"net/http"
	"time"
	"encoding/json"
	"net"
	"os"

	// Prometheus imports
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

// ============================================================================
// Prometheus Metrics
// ============================================================================
var (
	httpRequestsTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "recommendation_http_requests_total",
			Help: "Total number of HTTP requests",
		},
		[]string{"method", "endpoint", "status"},
	)

	httpRequestDuration = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "recommendation_http_request_duration_seconds",
			Help:    "HTTP request duration in seconds",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"method", "endpoint"},
	)

	recommendationsServed = promauto.NewCounter(
		prometheus.CounterOpts{
			Name: "recommendation_origami_of_day_total",
			Help: "Total number of origami-of-the-day recommendations served",
		},
	)
)

// ============================================================================
// Prometheus Middleware
// ============================================================================
func prometheusMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		path := c.FullPath()
		if path == "" {
			path = c.Request.URL.Path
		}

		// Process request
		c.Next()

		// Record metrics
		duration := time.Since(start).Seconds()
		status := c.Writer.Status()

		httpRequestsTotal.WithLabelValues(
			c.Request.Method,
			path,
			http.StatusText(status),
		).Inc()

		httpRequestDuration.WithLabelValues(
			c.Request.Method,
			path,
		).Observe(duration)
	}
}

// ============================================================================
// Configuration
// ============================================================================

// Config represents the structure of our configuration file.
type Config struct {
    Version string `json:"version"`
}

// loadConfig reads the configuration file and returns a Config struct.
func loadConfig() (Config, error) {
    file, err := os.Open("config.json")
    if err != nil {
        return Config{}, err
    }
    defer file.Close()

    config := Config{}
    decoder := json.NewDecoder(file)
    err = decoder.Decode(&config)
    return config, err
}

// ============================================================================
// System Info
// ============================================================================

type SystemInfo struct {
	Hostname      string
	IPAddress     string
	IsContainer   bool
	IsKubernetes  bool
}

func GetSystemInfo() SystemInfo {
	hostname, _ := os.Hostname()
	addrs, _ := net.InterfaceAddrs()
	ip := ""
	for _, addr := range addrs {
		if ipnet, ok := addr.(*net.IPNet); ok && !ipnet.IP.IsLoopback() {
			if ipnet.IP.To4() != nil {
				ip = ipnet.IP.String()
				break
			}
		}
	}
	isContainer := false
	if _, err := os.Stat("/.dockerenv"); err == nil {
		isContainer = true
	}
	isKubernetes := false

	return SystemInfo{
		Hostname:      hostname,
		IPAddress:     ip,
		IsContainer:   isContainer,
		IsKubernetes: isKubernetes,
	}
}

// ============================================================================
// Handlers
// ============================================================================

func getRecommendationStatus(c *gin.Context) {
	status := "operational"
	c.JSON(http.StatusOK, gin.H{
		"status": status,
	})
}

func renderHomePage(c *gin.Context) {
	config, err := loadConfig()
	if err != nil {
		c.String(http.StatusInternalServerError, "Internal Server Error")
		return
	}

	systemInfo := GetSystemInfo()

	c.HTML(http.StatusOK, "index.html", gin.H{
		"Year":        time.Now().Year(),
		"Version":     config.Version,
		"SystemInfo":  systemInfo,
	})
}

// Wrapped origami handler to count recommendations
func getOrigamiOfTheDayWithMetrics(c *gin.Context) {
	recommendationsServed.Inc()
	api.GetOrigamiOfTheDay(c)
}

// ============================================================================
// Main Function
// ============================================================================

func main() {
	router := gin.Default()

	// Add Prometheus middleware
	router.Use(prometheusMiddleware())

	// Load HTML files
	router.LoadHTMLGlob("templates/*")

	// Set path to serve static files
	router.Static("/static", "./static")

	// ========================================================================
	// Metrics and Health Endpoints
	// ========================================================================
	router.GET("/metrics", gin.WrapH(promhttp.Handler()))
	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "healthy"})
	})

	// ========================================================================
	// Application Routes
	// ========================================================================
	router.GET("/", renderHomePage)
	router.GET("/api/origami-of-the-day", getOrigamiOfTheDayWithMetrics)
	router.GET("/api/recommendation-status", getRecommendationStatus)

	// Start the server on port 8080
	router.Run(":8080")
}
