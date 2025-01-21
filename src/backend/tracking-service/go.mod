//
// go.mod for the real-time location tracking service
// Module: github.com/dogwalking/tracking-service
// Version: v1.0.0
// Implements MQTT for real-time communication, WebSockets for
// client updates, and TimescaleDB/pgx for location data storage.
//

module github.com/dogwalking/tracking-service

go 1.21

//
// Required dependencies for MQTT, WebSocket, PostgreSQL/TimescaleDB driver,
// metrics, logging, and configuration management.
//
require (
	// MQTT client for real-time location updates with QoS support
	github.com/eclipse/paho.mqtt.golang v1.4.3

	// WebSocket support for client communication
	github.com/gorilla/websocket v1.5.0

	// PostgreSQL/TimescaleDB driver with connection pooling
	github.com/jackc/pgx/v5 v5.4.3

	// Prometheus metrics integration for performance tracking
	github.com/prometheus/client_golang v1.16.0

	// High-performance structured logging
	go.uber.org/zap v1.25.0

	// Configuration management library for environment variables and file support
	github.com/spf13/viper v1.16.0
)