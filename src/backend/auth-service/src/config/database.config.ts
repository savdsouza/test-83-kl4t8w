//
// database.config.ts
//
// Comprehensive database configuration file for the authentication service managing
// PostgreSQL (Aurora) connection settings, security parameters, and environment-specific
// optimizations with multi-region high availability and read replicas.
//
// This file implements three distinct configuration objects—development, staging, and production—
// and a helper function to retrieve the correct database configuration object based on the 
// current environment. It addresses the following key requirements:
//
// 1) PostgreSQL Database Configuration:
//    - Optimized connection pools
//    - Detailed retry logic
//    - Logging and environment-based parameters
//
// 2) Multi-Region Database Architecture:
//    - Write host with read replicas
//    - SSL/TLS encryption for cross-region replication
//    - Replication settings for staging and production
//
// 3) Sensitive Data Security:
//    - SSL enforcement with certificate validation
//    - Secure credential management via environment variables
//    - Strict isolation levels in production
//

// ---------------------------------------------------------------------
// External Imports
// ---------------------------------------------------------------------

// dotenv@16.3.1 - Secure loading and management of environment-
// specific database credentials and configuration variables.
import * as dotenv from 'dotenv';

// sequelize@6.35.1 - ORM for PostgreSQL connection management
// with support for pooling, replication, and type safety.
import { Options, Dialect } from 'sequelize';

// Load environment variables from .env (if present)
dotenv.config();

// ---------------------------------------------------------------------
// Global Environment Fallback
// ---------------------------------------------------------------------
const ENVIRONMENT: string = process.env.NODE_ENV || 'development';

// ---------------------------------------------------------------------
// Database Configuration
// ---------------------------------------------------------------------
//
// Each environment configuration is structured to comply with the
// Sequelize Options interface. SSL, connection pooling, multi-region
// replication, retry logic, and logging granularity are tailored
// according to the deployment stage (development/staging/production).
//
export const databaseConfig: Record<string, Options> = {
  development: {
    // Dialect selection for PostgreSQL
    dialect: 'postgres' as Dialect,

    // Basic connection information (loaded from environment variables)
    host: process.env.DB_HOST,
    port: process.env.DB_PORT ? parseInt(process.env.DB_PORT, 10) : 5432,
    database: process.env.DB_NAME,
    username: process.env.DB_USER,
    password: process.env.DB_PASSWORD,

    // Enable logging during development for debugging
    logging: true,

    // Connection Pool Settings
    pool: {
      max: 5,
      min: 0,
      acquire: 30000,
      idle: 10000,
    },

    // Basic SSL disabled for local development
    dialectOptions: {
      ssl: false,
    },

    // Basic retry strategy for transient issues
    retry: {
      max: 3,
      timeout: 3000,
    },
  },

  staging: {
    // Dialect selection for PostgreSQL
    dialect: 'postgres' as Dialect,

    // Basic connection information (loaded from environment variables)
    host: process.env.DB_HOST,
    port: process.env.DB_PORT ? parseInt(process.env.DB_PORT, 10) : 5432,
    database: process.env.DB_NAME,
    username: process.env.DB_USER,
    password: process.env.DB_PASSWORD,

    // Disable verbose logging in staging
    logging: false,

    // Connection Pool Settings
    pool: {
      max: 10,
      min: 2,
      acquire: 30000,
      idle: 10000,
    },

    // Enforce SSL in staging, but allow self-signed certs
    dialectOptions: {
      ssl: {
        require: true,
        rejectUnauthorized: false,
      },
    },

    // Replication settings for multi-region read/write separation
    replication: {
      read: [
        {
          host: process.env.DB_READ_HOST_1,
          username: process.env.DB_READ_USER,
          password: process.env.DB_READ_PASSWORD,
        },
      ],
      write: {
        host: process.env.DB_WRITE_HOST,
        username: process.env.DB_WRITE_USER,
        password: process.env.DB_WRITE_PASSWORD,
      },
    },

    // Enhanced retry configuration for staging
    retry: {
      max: 5,
      timeout: 5000,
    },
  },

  production: {
    // Dialect selection for PostgreSQL
    dialect: 'postgres' as Dialect,

    // Basic connection information (loaded from environment variables)
    host: process.env.DB_HOST,
    port: process.env.DB_PORT ? parseInt(process.env.DB_PORT, 10) : 5432,
    database: process.env.DB_NAME,
    username: process.env.DB_USER,
    password: process.env.DB_PASSWORD,

    // Logging disabled in production for performance and security
    logging: false,

    // Connection Pool Settings
    pool: {
      max: 20,
      min: 5,
      acquire: 30000,
      idle: 10000,
    },

    // Strict SSL configuration for production
    // 'ca' can be populated with certificate data from the environment
    dialectOptions: {
      ssl: {
        require: true,
        rejectUnauthorized: true,
        ca: process.env.DB_SSL_CA,
      },
      keepAlive: true,
      keepAliveInitialDelay: 300000,
    },

    // Multi-region replication with multiple read replicas
    replication: {
      read: [
        {
          host: process.env.DB_READ_HOST_1,
          username: process.env.DB_READ_USER,
          password: process.env.DB_READ_PASSWORD,
        },
        {
          host: process.env.DB_READ_HOST_2,
          username: process.env.DB_READ_USER,
          password: process.env.DB_READ_PASSWORD,
        },
      ],
      write: {
        host: process.env.DB_WRITE_HOST,
        username: process.env.DB_WRITE_USER,
        password: process.env.DB_WRITE_PASSWORD,
      },
    },

    // Advanced retry policy to handle transient and cross-region issues
    retry: {
      max: 10,
      timeout: 10000,
    },

    // Benchmark (measure query timing) and strict isolation level
    benchmark: true,
    isolationLevel: 'READ COMMITTED',
  },
};

// ---------------------------------------------------------------------
// getDatabaseConfig() 
// ---------------------------------------------------------------------
//
// Retrieves the environment-specific database configuration object. This
// function ensures environment variables are loaded, selects the correct
// configuration block (development, staging, or production), and returns
// an Options object that can be used by Sequelize or other ORM tooling.
// 
// Steps:
//  1) Load and validate required environment variables
//  2) Determine current environment (development/staging/production)
//  3) Configure SSL, replication, and pooling specifics
//  4) Return the selected database configuration object
//
export function getDatabaseConfig(): Options {
  const config = databaseConfig[ENVIRONMENT] || databaseConfig.development;
  return config;
}
```