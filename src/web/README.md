# Dog Walking Platform - Admin Dashboard

Enterprise-grade web-based administration interface for comprehensive management of the dog walking service platform. This admin dashboard is designed to monitor, manage, and analyze all aspects of the Dog Walking Platform, including real-time walk tracking, user profiles, payment status, and system-wide metrics. By leveraging modern tooling (React, TypeScript, and Vite) along with robust security and deployment practices, this solution delivers a scalable, maintainable, and highly performant management environment.

---

## Table of Contents
1. [Overview](#overview)  
2. [Features](#features)  
3. [Technology Stack](#technology-stack)  
4. [Getting Started](#getting-started)  
5. [Project Structure](#project-structure)  
6. [Development](#development)  
7. [Testing](#testing)  
8. [Deployment](#deployment)  
9. [Security](#security)  
10. [Contributing](#contributing)  
11. [Troubleshooting](#troubleshooting)

---

## Overview

The web admin dashboard provides powerful capabilities to:
- Manage dog walking schedules, assign walks, and oversee real-time tracking of ongoing sessions.
- Monitor system health, application metrics, and performance thresholds using integrated system monitoring.
- Control and configure application-wide settings such as user role assignments, payment methods, verification processes, and more.
- Access advanced analytics for usage trends, walk history, dog walker performance, and financial operations.

This console is designed to complement the mobile applications, bridging operational tasks with administrative oversight. It integrates tightly with the same back-end microservices that power the Dog Walking Platform, ensuring consistent real-time data and unified user experiences.

---

## Features

1. **Real-time Monitoring**  
   - View ongoing walks with live GPS positions using Socket.io and Google Maps API.  
   - Receive instant notifications for key events (walk starts, emergencies, cancellations).

2. **User & Walker Management**  
   - Create, update, and deactivate owner/walker accounts.  
   - Handle verification requirements: background checks, identity validations, and payment setup.

3. **System-wide Analytics**  
   - Visualize system metrics, e.g., number of active walks, daily bookings, user retention.  
   - Leverage Recharts and chart.js to deliver interactive dashboards.

4. **Reporting & Audits**  
   - Generate comprehensive walk reports, payment summaries, and performance reviews.  
   - Integrate with third-party logging and auditing solutions (@company/audit-logger, Winston).

5. **Security & RBAC**  
   - Enforce role-based access control (RBAC) for granular security.  
   - Support advanced authentication flows (JWT-based sessions, multi-factor support).

6. **System Monitoring**  
   - Track service health, logs, error rates, and application performance.  
   - Display aggregated metrics in a centralized admin UI and configure alert triggers.

---

## Technology Stack

This admin dashboard is built with a modern front-end technology stack to ensure reliability, performance, and developer productivity:

- **React 18.2.0 with TypeScript**  
  Type-safe development leveraging React hooks, React Router, and React Context for advanced state management. Strict typing helps prevent common runtime errors and maintain code quality for enterprise features.

- **Vite 4.4.0**  
  Lightning-fast development environment for immediate Hot Module Replacement (HMR), minimal overhead, and modern build optimizations.

- **React Query**  
  Efficient data fetching and caching layer that reduces boilerplate and ensures real-time synchronization with remote APIs, including the booking, user, and payments services.

- **Socket.io**  
  Real-time communications for walk tracking, system notifications, and instant updates within the admin interface.

- **Google Maps API**  
  Interactive map components for live location tracking, geolocation services, route display, and walk clustering.

- **Recharts**  
  Comprehensive chart library for analytics dashboards and advanced data visualizations (e.g., daily booking volumes, monthly revenues, walker performance metrics).

- **Jest and React Testing Library**  
  Comprehensive testing framework for unit, integration, and snapshot tests, ensuring reliability and maintainability across user journeys.

- **Material-UI (MUI)**  
  Enterprise-grade React UI components that provide consistent styling, accessibility, and theming options.

- **Redux Toolkit**  
  Robust global state management solution to handle cross-cutting concerns such as notifications, user sessions, and real-time updates.

- **React Router 6**  
  Provides route-based code splitting and navigational structures for multi-page workflows with optional protected routes.

This combination aligns perfectly with the platform’s requirement for multi-user moderation, real-time oversight, and advanced analytics.

---

## Getting Started

Follow these guidelines to set up and launch the admin dashboard in your local environment.

### Prerequisites

Ensure you have the following installed and configured on your machine:
- Node.js >= 16.0.0  
- npm >= 8.0.0  
- Git >= 2.30.0  

### Repository Clone and Setup

1. **Clone the Repository**  
   ```bash
   git clone https://github.com/your-company/dog-walking-admin.git
   cd dog-walking-admin
   ```
2. **Install Dependencies**  
   Applications rely on multiple libraries and frameworks. The `package.json` file defines them under `"dependencies"` and `"devDependencies"`. To install:
   ```bash
   npm install
   ```

3. **Environment Configuration**  
   - Create a copy of `.env.example` as `.env`.  
   - Populate environment variables such as `VITE_API_URL`, real-time subscription endpoints, Google Maps API key, and other relevant settings.  
   - Example environment file snippet:
     ```env
     VITE_API_URL="https://api.your-dog-walking-platform.com"
     VITE_MAPS_API_KEY="YOUR_GOOGLE_MAPS_API_KEY"
     VITE_SOCKET_URL="wss://realtime.your-dog-walking-platform.com"
     ```

---

## Project Structure

A well-organized file structure ensures maintainability and clarity throughout the development lifecycle. Below is an overview:

```
.
├── src
│   ├── assets        // Static assets and resources (images, icons, etc.)
│   ├── components    // Reusable React components with TypeScript definitions
│   ├── contexts      // React Context providers for global state management
│   ├── hooks         // Custom React hooks for shared functionalities
│   ├── layouts       // Page layout components and high-level templates
│   ├── pages         // Main application pages and routes
│   ├── services      // API integrations and external services with type safety
│   ├── styles        // Global styles, themes, and design tokens
│   ├── types         // TypeScript type definitions and interfaces
│   ├── utils         // Utility functions and helper methods
│   ├── validation    // Form and data validation schemas
│   ├── config        // Application and environment configuration
│   ├── store         // Redux store configuration and slices
│   ├── api           // API client and endpoints configuration
│   └── tests         // Shared test utilities, mocks, and fixtures
├── package.json      // Project metadata, scripts, dependencies
├── tsconfig.json     // TypeScript configuration for strict type checking
├── vite.config.ts    // Vite configuration for build and dev server
└── README.md         // Project documentation (this file)
```

---

## Development

During development, the primary commands and workflows can be found in the `"scripts"` section of `package.json`. Some critical scripts:

- **Start Development Server**
  ```bash
  npm run dev
  ```
  Launches the Vite-powered development server with hot reloading. Open your browser to http://localhost:3000 or the designated port.

- **Type Checking**
  ```bash
  npm run typecheck
  ```
  Runs the TypeScript compiler in `--noEmit` mode to detect and report type errors. Internally references rules in `tsconfig.json` under `"compilerOptions"`.

- **Linting & Formatting**
  ```bash
  npm run lint
  npm run lint:fix
  npm run format
  ```
  Uses `eslint` (with recommended React and TypeScript rules) and `prettier` to maintain consistent code quality and styling.

- **API and Real-time Mocking**  
  During development, certain endpoints or WebSocket connections (Socket.io) can be mocked. Integrate a local mocking server if needed and point `VITE_API_URL` and `VITE_SOCKET_URL` to your local environment.

- **Advanced Monitoring Integration**  
  For local debugging of system metrics or performance, enable any relevant environment variables (e.g., `VITE_MONITORING_ENDPOINT`) to visualize custom events or logs directly in the admin.

---

## Testing

Comprehensive testing ensures reliability and stability. This project uses **Jest** and **React Testing Library**.

- **Run All Tests**
  ```bash
  npm run test
  ```
  Executes unit and integration tests. Configured in `package.json` under `"jest"` with an environment of `jsdom`.

- **Test Coverage**
  ```bash
  npm run test:coverage
  ```
  Generates a coverage report highlighting statements, branches, functions, and lines tested.

- **Watch Mode**
  ```bash
  npm run test:watch
  ```
  Automatically reruns tests on file changes, aiding rapid feedback during development.

- **Common Testing Scenarios**
  - **UI Components**: Snapshots, event interactions, and layout responsiveness.
  - **Hooks**: Behavior validation for custom React hooks (e.g., useAuth, useSocket).
  - **Services**: API calls tested with mocked responses to ensure correct data handling.

---

## Deployment

1. **Production Build**
   ```bash
   npm run build
   ```
   Compiles TypeScript, bundles assets via Vite, and outputs a production-ready `dist/` directory.

2. **Preview Mode**
   ```bash
   npm run preview
   ```
   Locally serves the built application on a static server to mimic production behavior.

3. **Cloud Deployment**  
   Deploy the contents of `dist/` to your preferred environment:
   - **AWS S3 + CloudFront** for serverless hosting.  
   - **Docker** container images for ECS or Kubernetes.  
   - **Static hosting services** (Netlify, Vercel, etc.).

4. **Application Configuration**  
   Ensure environment variables are appropriately set in your production environment (including API endpoints, real-time endpoints, and Google Maps) to match the production back-end microservices.

---

## Security

Security is paramount in administering sensitive data and functionalities:

- **JWT-based Authentication**  
  Verifies user tokens before granting admin dashboard access. Tokens must be transmitted securely (HTTPS) and validated against role claims (e.g., admin privileges).

- **Role-Based Access Control (RBAC)**  
  Uses granular roles (admin, support, superadmin) to define allowable actions. The UI and API calls are restricted based on user roles.

- **API Security Best Practices**  
  Implements rate limiting, circuit breakers (`circuit-breaker-js`), and secure request validation to mitigate DDoS or malicious request attacks.

- **Data Encryption**  
  Uses `crypto-js` or external encryption modules (@security-utils/core) for sensitive fields. Ensures encryption at rest and in-transit, aligning with the broader system’s encryption strategy.

- **Security Compliance Documentation**  
  Aligns with major guidelines like GDPR for data privacy and PCI DSS for payment processing. Audits are captured by `@company/audit-logger` for administrative actions.

- **Audit Logging**  
  Logs user sessions, critical actions (data export, user deactivation, role changes, etc.), and potential anomalies to enable forensic analysis in case of incidents.

---

## Contributing

We welcome contributions that improve functionality, performance, and usability:

1. **Fork & Branch**  
   - Fork the repository on GitHub.
   - Create a new branch (`feature/my-improvement` or `bugfix/issue-123`).

2. **Implement & Test**  
   - Write clear, concise code.
   - Update or add tests to maintain coverage.  
   - Follow linting and formatting standards (`npm run lint:fix` and `npm run format`).

3. **Pull Request**  
   - Submit a pull request with an informative description.  
   - Ensure that all checks passed (CI, tests, coverage, etc.).  
   - Provide additional documentation if necessary.

4. **Code Review**  
   - The project maintainers will review your changes and suggest improvements or merged acceptance.

---

## Troubleshooting

Below are some frequently encountered issues and possible resolutions:

1. **Port Conflicts**  
   - The default Vite dev server runs on `3000`. Check if any other process is using the port, or define a custom port via `vite.config.ts` or `npm run dev -- --port 3001`.

2. **Environment Variables Not Loaded**  
   - Verify `.env` file is present at the root. Confirm the variable name matches usage in your code. Check that `import.meta.env` usage is correct in `.ts/.tsx` files.

3. **API Errors**  
   - Confirm your `VITE_API_URL` or real-time WebSocket endpoint points to a valid, accessible environment.  
   - Check if the user roles (admin privileges) are correctly assigned.

4. **Build Failures**  
   - Refer to type checking errors (`npm run typecheck`) or linting issues.  
   - Ensure dependencies in `package.json` and types in `tsconfig.json` remain synchronized.

5. **Outdated Dependencies**  
   - Regularly run `npm outdated` to check for new releases.  
   - Update carefully to avoid breaking changes in major library upgrades.

For additional queries or persistent issues, please open an issue in the repository or contact the project maintainers directly.

---

> © 2023 Dog Walking Platform. All rights reserved.  
> This admin dashboard is part of the larger Dog Walking Platform and is maintained with active community and company support.