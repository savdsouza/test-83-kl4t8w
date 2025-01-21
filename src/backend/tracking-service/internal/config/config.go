//
// Go 1.21
//
// Package config provides a robust, enterprise-grade configuration management solution
// for the Tracking Service. It loads and validates all necessary settings related to
// MQTT broker connectivity, TimescaleDB parameters, and service-level configurations
// such as geofencing, location updates, and session timeouts. Comprehensive validation
// ensures integrity and security of the configuration.
//
// This package strictly follows production-ready standards and fully addresses
// the requirements for real-time location tracking, TimescaleDB storage settings,
// and MQTT-based communication patterns outlined in the technical specifications.
//
package config

// ------------------------
// External Imports
// ------------------------
import (
	"os"       // go1.21 - For reading environment variables securely
	"time"     // go1.21 - For duration and timeout configurations in service settings
	"strconv"  // go1.21 - For string-to-numeric parsing with error handling
	"fmt"      // go1.21 - For formatted error output
	"strings"  // go1.21 - For constructing detailed validation error messages
)

// ------------------------
// Global Default Constants
// ------------------------
//
// Default configuration constants for use as sane fallbacks
// when environment variables or external settings are not provided.
//
const (
	DefaultMQTTPort                = 1883
	DefaultDBPort                  = 5432
	DefaultGeofenceRadius          = 0.5 // kilometers
	DefaultMaxConnections          = 100
	DefaultLocationUpdateInterval  = 5 * time.Second
	DefaultSessionTimeout          = 30 * time.Minute
)

// ------------------------
// MQTTConfig Struct
// ------------------------
//
// MQTTConfig defines core MQTT connection parameters,
// including security settings (TLS) and reconnect handling.
//
type MQTTConfig struct {
	Host             string
	Port             int
	Username         string
	Password         string
	ConnectionTimeout time.Duration
	KeepAlive         time.Duration
	TLSEnabled        bool
	QoS               int
	RetryInterval     time.Duration
}

// ------------------------
// DBConfig Struct
// ------------------------
//
// DBConfig defines TimescaleDB connection parameters,
// including credentials, connection pooling, timeouts,
// and other essential database settings.
//
type DBConfig struct {
	Host                 string
	Port                 int
	Database             string
	Username             string
	Password             string
	MaxConnections       int
	ConnectionTimeout    time.Duration
	MaxIdleConnections   int
	MaxConnectionLifetime time.Duration
}

// ------------------------
// ServiceConfig Struct
// ------------------------
//
// ServiceConfig defines general service-level parameters such as geofencing radius,
// location update intervals, session timeouts, and other tracking-related settings.
//
type ServiceConfig struct {
	GeofenceRadius        float64
	LocationUpdateInterval time.Duration
	SessionTimeout         time.Duration
	MaxConcurrentSessions  int
	MinAccuracy            float64
	MaxLocationHistory     int
	StaleLocationThreshold time.Duration
}

// ------------------------
// Config Struct
// ------------------------
//
// Config is the main configuration structure for the tracking service,
// consolidating MQTT, DB, and Service-level configs. It offers a Validate method
// to ensure all fields are thoroughly checked and safe for production use.
//
type Config struct {
	MQTT    MQTTConfig
	Database DBConfig
	Service ServiceConfig
}

// ------------------------
// Validate Method
// ------------------------
//
// Validate performs comprehensive validation on all configuration fields.
// It aggregates any errors found and returns them as a single error. If no
// issues are found, it returns nil.
//
// Returns:
//   error: A descriptive error if any validation checks fail, or nil otherwise.
//
func (c *Config) Validate() error {
	var validationErrs []string

	// ------------------------
	// MQTT Validation
	// ------------------------
	if strings.TrimSpace(c.MQTT.Host) == "" {
		validationErrs = append(validationErrs, "MQTT host is empty")
	}
	if c.MQTT.Port <= 0 || c.MQTT.Port > 65535 {
		validationErrs = append(validationErrs, fmt.Sprintf("MQTT port %d is out of valid range", c.MQTT.Port))
	}
	if c.MQTT.ConnectionTimeout <= 0 {
		validationErrs = append(validationErrs, "MQTT connection timeout must be greater than zero")
	}
	if c.MQTT.KeepAlive < 0 {
		validationErrs = append(validationErrs, "MQTT keep-alive cannot be negative")
	}
	if c.MQTT.QoS < 0 || c.MQTT.QoS > 2 {
		validationErrs = append(validationErrs, fmt.Sprintf("MQTT QoS %d is invalid; must be 0, 1, or 2", c.MQTT.QoS))
	}
	if c.MQTT.RetryInterval < 0 {
		validationErrs = append(validationErrs, "MQTT retry interval cannot be negative")
	}

	// ------------------------
	// Database Validation
	// ------------------------
	if strings.TrimSpace(c.Database.Host) == "" {
		validationErrs = append(validationErrs, "DB host is empty")
	}
	if c.Database.Port <= 0 || c.Database.Port > 65535 {
		validationErrs = append(validationErrs, fmt.Sprintf("DB port %d is out of valid range", c.Database.Port))
	}
	if strings.TrimSpace(c.Database.Database) == "" {
		validationErrs = append(validationErrs, "DB database name is empty")
	}
	if c.Database.MaxConnections < 1 {
		validationErrs = append(validationErrs, fmt.Sprintf("DB max connections %d is invalid; must be at least 1", c.Database.MaxConnections))
	}
	if c.Database.ConnectionTimeout < 0 {
		validationErrs = append(validationErrs, "DB connection timeout cannot be negative")
	}
	if c.Database.MaxIdleConnections < 0 {
		validationErrs = append(validationErrs, fmt.Sprintf("DB max idle connections %d cannot be negative", c.Database.MaxIdleConnections))
	}
	if c.Database.MaxConnectionLifetime < 0 {
		validationErrs = append(validationErrs, "DB max connection lifetime cannot be negative")
	}

	// ------------------------
	// Service Validation
	// ------------------------
	if c.Service.GeofenceRadius <= 0 {
		validationErrs = append(validationErrs, fmt.Sprintf("service geofence radius %f must be positive", c.Service.GeofenceRadius))
	}
	if c.Service.LocationUpdateInterval <= 0 {
		validationErrs = append(validationErrs, "service location update interval must be greater than zero")
	}
	if c.Service.SessionTimeout <= 0 {
		validationErrs = append(validationErrs, "service session timeout must be greater than zero")
	}
	if c.Service.MaxConcurrentSessions < 0 {
		validationErrs = append(validationErrs, fmt.Sprintf("service max concurrent sessions %d cannot be negative", c.Service.MaxConcurrentSessions))
	}
	if c.Service.MinAccuracy < 0 {
		validationErrs = append(validationErrs, fmt.Sprintf("service minimum accuracy %f cannot be negative", c.Service.MinAccuracy))
	}
	if c.Service.MaxLocationHistory < 0 {
		validationErrs = append(validationErrs, fmt.Sprintf("service max location history %d cannot be negative", c.Service.MaxLocationHistory))
	}
	if c.Service.StaleLocationThreshold < 0 {
		validationErrs = append(validationErrs, "service stale location threshold cannot be negative")
	}

	// ------------------------
	// Return Validation Errors
	// ------------------------
	if len(validationErrs) > 0 {
		return fmt.Errorf("configuration validation failed:\n - %s", strings.Join(validationErrs, "\n - "))
	}
	return nil
}

// ------------------------
// LoadConfig Function
// ------------------------
//
// LoadConfig reads the necessary environment variables, applies defaults,
// and returns a populated Config pointer. It ensures that all settings are
// validated before returning.
//
// Returns:
//   *Config: Populated configuration struct if successful
//   error:   Any error if configuration loading or validation fails
//
func LoadConfig() (*Config, error) {
	cfg := &Config{
		// --------------------------------
		// MQTT Configuration
		// --------------------------------
		MQTT: MQTTConfig{
			Host: getEnvWithDefault("MQTT_HOST", "localhost"),
		},
		Database: DBConfig{
			Host: getEnvWithDefault("DB_HOST", "localhost"),
		},
		Service: ServiceConfig{},
	}

	// -------------------------------
	// Parse numeric/bool/duration envs
	// for MQTT
	// -------------------------------
	mqttPortStr := getEnvWithDefault("MQTT_PORT", strconv.Itoa(DefaultMQTTPort))
	mqttPort, err := strconv.Atoi(mqttPortStr)
	if err != nil {
		mqttPort = DefaultMQTTPort
	}
	cfg.MQTT.Port = mqttPort

	cfg.MQTT.Username = getEnvWithDefault("MQTT_USER", "")
	cfg.MQTT.Password = getEnvWithDefault("MQTT_PASS", "")

	mqttTLSStr := getEnvWithDefault("MQTT_TLS_ENABLED", "false")
	mqttTLSVal, err := strconv.ParseBool(mqttTLSStr)
	if err != nil {
		mqttTLSVal = false
	}
	cfg.MQTT.TLSEnabled = mqttTLSVal

	mqttConnectionTimeoutStr := getEnvWithDefault("MQTT_CONNECTION_TIMEOUT", "10s")
	mqttConnTimeout, err := time.ParseDuration(mqttConnectionTimeoutStr)
	if err != nil {
		mqttConnTimeout = 10 * time.Second
	}
	cfg.MQTT.ConnectionTimeout = mqttConnTimeout

	mqttKeepAliveStr := getEnvWithDefault("MQTT_KEEP_ALIVE", "60s")
	mqttKeepAlive, err := time.ParseDuration(mqttKeepAliveStr)
	if err != nil {
		mqttKeepAlive = 60 * time.Second
	}
	cfg.MQTT.KeepAlive = mqttKeepAlive

	mqttQoSStr := getEnvWithDefault("MQTT_QOS", "0")
	mqttQoSVal, err := strconv.Atoi(mqttQoSStr)
	if err != nil {
		mqttQoSVal = 0
	}
	cfg.MQTT.QoS = mqttQoSVal

	mqttRetryIntervalStr := getEnvWithDefault("MQTT_RETRY_INTERVAL", "5s")
	mqttRetryInterval, err := time.ParseDuration(mqttRetryIntervalStr)
	if err != nil {
		mqttRetryInterval = 5 * time.Second
	}
	cfg.MQTT.RetryInterval = mqttRetryInterval

	// -------------------------------
	// Parse numeric/bool/duration envs
	// for Database
	// -------------------------------
	dbPortStr := getEnvWithDefault("DB_PORT", strconv.Itoa(DefaultDBPort))
	dbPort, err := strconv.Atoi(dbPortStr)
	if err != nil {
		dbPort = DefaultDBPort
	}
	cfg.Database.Port = dbPort

	cfg.Database.Database = getEnvWithDefault("DB_DATABASE", "tracking_db")
	cfg.Database.Username = getEnvWithDefault("DB_USER", "")
	cfg.Database.Password = getEnvWithDefault("DB_PASS", "")

	dbMaxConnStr := getEnvWithDefault("DB_MAX_CONNECTIONS", strconv.Itoa(DefaultMaxConnections))
	dbMaxConn, err := strconv.Atoi(dbMaxConnStr)
	if err != nil {
		dbMaxConn = DefaultMaxConnections
	}
	cfg.Database.MaxConnections = dbMaxConn

	dbConnTimeoutStr := getEnvWithDefault("DB_CONNECTION_TIMEOUT", "5s")
	dbConnTimeout, err := time.ParseDuration(dbConnTimeoutStr)
	if err != nil {
		dbConnTimeout = 5 * time.Second
	}
	cfg.Database.ConnectionTimeout = dbConnTimeout

	dbMaxIdleConnStr := getEnvWithDefault("DB_MAX_IDLE_CONNECTIONS", "10")
	dbMaxIdleConn, err := strconv.Atoi(dbMaxIdleConnStr)
	if err != nil {
		dbMaxIdleConn = 10
	}
	cfg.Database.MaxIdleConnections = dbMaxIdleConn

	dbMaxLifetimeStr := getEnvWithDefault("DB_MAX_CONNECTION_LIFETIME", "60m")
	dbMaxLifetime, err := time.ParseDuration(dbMaxLifetimeStr)
	if err != nil {
		dbMaxLifetime = 60 * time.Minute
	}
	cfg.Database.MaxConnectionLifetime = dbMaxLifetime

	// -------------------------------
	// Parse numeric/bool/duration envs
	// for Service-level configuration
	// -------------------------------
	geoRadiusStr := getEnvWithDefault("SERVICE_GEOFENCE_RADIUS", fmt.Sprintf("%f", DefaultGeofenceRadius))
	geoRadiusVal, err := strconv.ParseFloat(geoRadiusStr, 64)
	if err != nil {
		geoRadiusVal = DefaultGeofenceRadius
	}
	cfg.Service.GeofenceRadius = geoRadiusVal

	locUpdateIntStr := getEnvWithDefault("SERVICE_LOCATION_UPDATE_INTERVAL", "5s")
	locUpdateIntVal, err := time.ParseDuration(locUpdateIntStr)
	if err != nil {
		locUpdateIntVal = DefaultLocationUpdateInterval
	}
	cfg.Service.LocationUpdateInterval = locUpdateIntVal

	sessTimeoutStr := getEnvWithDefault("SERVICE_SESSION_TIMEOUT", "30m")
	sessTimeoutVal, err := time.ParseDuration(sessTimeoutStr)
	if err != nil {
		sessTimeoutVal = DefaultSessionTimeout
	}
	cfg.Service.SessionTimeout = sessTimeoutVal

	maxSessionsStr := getEnvWithDefault("SERVICE_MAX_CONCURRENT_SESSIONS", "10")
	maxSessionsVal, err := strconv.Atoi(maxSessionsStr)
	if err != nil {
		maxSessionsVal = 10
	}
	cfg.Service.MaxConcurrentSessions = maxSessionsVal

	minAccStr := getEnvWithDefault("SERVICE_MIN_ACCURACY", "10")
	minAccVal, err := strconv.ParseFloat(minAccStr, 64)
	if err != nil {
		minAccVal = 10.0
	}
	cfg.Service.MinAccuracy = minAccVal

	maxLocHistStr := getEnvWithDefault("SERVICE_MAX_LOCATION_HISTORY", "1000")
	maxLocHistVal, err := strconv.Atoi(maxLocHistStr)
	if err != nil {
		maxLocHistVal = 1000
	}
	cfg.Service.MaxLocationHistory = maxLocHistVal

	staleLocThresholdStr := getEnvWithDefault("SERVICE_STALE_LOCATION_THRESHOLD", "30s")
	staleLocThresholdVal, err := time.ParseDuration(staleLocThresholdStr)
	if err != nil {
		staleLocThresholdVal = 30 * time.Second
	}
	cfg.Service.StaleLocationThreshold = staleLocThresholdVal

	// -------------------------------
	// Validate the final configuration
	// -------------------------------
	if err := cfg.Validate(); err != nil {
		return nil, err
	}
	return cfg, nil
}

// ------------------------
// getEnvWithDefault Function
// ------------------------
//
// getEnvWithDefault is a secure helper function that checks the environment for a given key.
// If the key is empty or invalid, it returns the specified defaultValue. Otherwise, it returns
// the sanitized environment variable.
//
// Parameters:
//   key:          The environment variable name to look up.
//   defaultValue: The fallback value if no valid environment variable is found.
//
// Returns:
//   string:       The environment variable's value or the defaultValue.
//
func getEnvWithDefault(key string, defaultValue string) string {
	val, exists := os.LookupEnv(key)
	if !exists || strings.TrimSpace(val) == "" {
		return defaultValue
	}
	return strings.TrimSpace(val)
}