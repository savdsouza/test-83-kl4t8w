/**
 * Advanced request validation middleware for the API Gateway that implements
 * comprehensive schema validation, input sanitization, and security controls
 * with performance optimizations and enhanced error handling.
 */

// -----------------------------------------------------------------------------
// External Imports (with version comments)
// -----------------------------------------------------------------------------
import { Request, Response, NextFunction, RequestHandler } from 'express' // express@4.18.2
import Joi from 'joi' // joi@17.11.0
import sanitizeHtml from 'sanitize-html' // sanitize-html@2.11.0

// -----------------------------------------------------------------------------
// Internal Imports
// -----------------------------------------------------------------------------
import { ApiError } from '../types' // Standardized API error handling type definitions

// -----------------------------------------------------------------------------
// Global Interface: ValidationOptions
// -----------------------------------------------------------------------------
/**
 * ValidationOptions
 * Provides configuration for the validation process, enabling features such as
 * caching, stripping unknown fields, allowing unknown fields, aborting early on
 * errors, debugging, and performance-focused optimizations.
 */
export interface ValidationOptions {
  /**
   * If set to true, validation stops on the first detected error.
   */
  abortEarly: boolean

  /**
   * If set to true, unknown fields are removed from the validated data.
   */
  stripUnknown: boolean

  /**
   * If set to true, unknown fields are allowed and retained in the validated data.
   */
  allowUnknown?: boolean

  /**
   * If set to true, compiled schemas or validation results can be cached for
   * faster subsequent validations. Implementation details may vary.
   */
  cache?: boolean

  /**
   * If set to true, debugging information is logged during validation.
   */
  debug?: boolean

  /**
   * If set to true, performance-optimized validation is attempted, possibly
   * reducing overhead at the expense of certain runtime checks.
   */
  performanceMode?: boolean
}

// -----------------------------------------------------------------------------
// Named Export: sanitizeInput
// -----------------------------------------------------------------------------
/**
 * sanitizeInput
 * Advanced input sanitization function with recursive object traversal and type
 * preservation. It thoroughly cleans string values (protecting against HTML or
 * script injection) while retaining the structure and types of all other data.
 *
 * Steps:
 *  1. Check input type and handle null/undefined.
 *  2. Initialize sanitization options based on data type.
 *  3. Recursively traverse object properties.
 *  4. Apply type-specific sanitization rules.
 *  5. Preserve non-string data types.
 *  6. Handle arrays and nested objects.
 *  7. Apply HTML sanitization to string values.
 *  8. Validate sanitized output.
 *  9. Return sanitized object with preserved structure.
 *
 * @param data The data object or primitive to sanitize.
 * @returns A deeply sanitized data object with all string fields cleaned.
 */
export function sanitizeInput(data: unknown): unknown {
  // 1. Handle null or undefined data, return it as is.
  if (data === null || data === undefined) {
    return data
  }

  // 2. If data is a string, sanitize with HTML sanitization rules.
  if (typeof data === 'string') {
    // Apply sanitize-html for thorough XSS prevention while preserving safe content.
    const sanitizedString = sanitizeHtml(data, {
      allowedTags: [], // Removes all HTML tags
      allowedAttributes: {}
    })
    return sanitizedString
  }

  // 3. If data is an object (Array or Record), recursively sanitize each element/property.
  if (typeof data === 'object') {
    // Handle arrays by mapping each element through sanitizeInput
    if (Array.isArray(data)) {
      return data.map((item) => sanitizeInput(item))
    }

    // For plain objects, recurse over each key-value pair
    const sanitizedObject: Record<string, unknown> = {}
    for (const [key, value] of Object.entries(data)) {
      sanitizedObject[key] = sanitizeInput(value)
    }
    return sanitizedObject
  }

  // 4. For other data types (number, boolean, etc.), return as is to preserve type.
  return data
}

// -----------------------------------------------------------------------------
// Private Helpers: Caching Mechanisms (Optional Implementation Example)
// -----------------------------------------------------------------------------
/**
 * Potential caching structure for compiled Joi schemas or validation results.
 * This map can store schema references or partial results keyed by a schema
 * identifier. The actual usage depends on the broader application context.
 */
const schemaCache = new WeakMap<Joi.Schema, Joi.Schema>()

/**
 * compileSchemaWithCaching
 * An optional helper function that caches Joi schemas if enabled in ValidationOptions.
 * In real-world usage, the key might incorporate a unique schema identifier.
 *
 * @param schema The Joi schema to compile or retrieve from cache.
 * @param options Validation options controlling caching.
 * @returns A cached or newly compiled Joi schema.
 */
function compileSchemaWithCaching(schema: Joi.Schema, options: ValidationOptions): Joi.Schema {
  if (!options.cache) {
    // If caching is disabled, return the schema directly.
    return schema
  }

  // If schema is already in cache, retrieve it
  const cached = schemaCache.get(schema)
  if (cached) {
    return cached
  }

  // Otherwise, simply store and return the same schema reference.
  // In advanced systems, we might compile or preprocess the schema here.
  schemaCache.set(schema, schema)
  return schema
}

// -----------------------------------------------------------------------------
// Default Export: validateSchema
// -----------------------------------------------------------------------------
/**
 * validateSchema
 * Enhanced higher-order function that creates optimized validation middleware
 * with support for complex schemas, caching, and comprehensive validation
 * options.
 *
 * Steps:
 *  1. Initialize schema compilation with caching if enabled.
 *  2. Return optimized middleware function with (req, res, next) arguments.
 *  3. Extract validation targets from request body, query, and params.
 *  4. Apply schema validation with configured options.
 *  5. Handle validation errors with detailed messages.
 *  6. Perform recursive input sanitization.
 *  7. Cache validation results if enabled (optional advanced usage).
 *  8. Attach validated and sanitized data to request object.
 *  9. Track validation metrics if debug mode enabled.
 *  10. Proceed to next middleware on success.
 *
 * @param schema A Joi schema defining request requirements for body, query, and params.
 * @param options ValidationOptions controlling caching, debugging, performance, etc.
 * @returns An Express RequestHandler function that validates incoming requests.
 */
export default function validateSchema(
  schema: Joi.Schema,
  options: ValidationOptions
): RequestHandler {
  // 1. Initialize schema compilation (and caching if enabled).
  const compiledSchema = compileSchemaWithCaching(schema, options)

  // 2. Return the middleware function that Express will call.
  return (req: Request, res: Response, next: NextFunction): void => {
    const startTime = Date.now()

    // 3. Prepare the object that will be validated, merging body, query, and params.
    const dataToValidate = {
      body: req.body,
      query: req.query,
      params: req.params
    }

    // 4. Apply Joi validation with the corresponding validation options.
    const joiOptions: Joi.ValidationOptions = {
      abortEarly: options.abortEarly,
      allowUnknown: options.allowUnknown,
      stripUnknown: options.stripUnknown
    }

    const { error, value } = compiledSchema.validate(dataToValidate, joiOptions)

    // 5. Handle validation errors with detailed messages.
    if (error) {
      const validationError: ApiError = {
        code: 400,
        message: 'Validation Error',
        details: { joiMessage: error.message },
        stack: process.env.NODE_ENV !== 'production' ? error.stack || '' : '',
        timestamp: new Date()
      }
      return res.status(400).json(validationError)
    }

    // 6. Perform recursive input sanitization on the validated data.
    const sanitizedValue = sanitizeInput(value) as Record<string, unknown>

    // 7. (Optional) Cache validation results if needed. Implementation can vary:
    //    For example, we could store sanitizedValue in a redis or memory cache
    //    keyed by request or schema, etc.

    // 8. Attach validated and sanitized data to the request object.
    req.body = sanitizedValue.body || {}
    req.query = sanitizedValue.query || {}
    req.params = sanitizedValue.params || {}

    // 9. Track validation metrics if debug mode is enabled.
    if (options.debug) {
      const endTime = Date.now()
      const durationMs = endTime - startTime
      // eslint-disable-next-line no-console
      console.debug('[validateSchema] Debug info:', {
        requestPath: req.originalUrl,
        validationTimeMs: durationMs,
        performanceMode: options.performanceMode
      })
    }

    // 10. Proceed to the next middleware in the chain.
    return next()
  }
}
```