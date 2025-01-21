/***************************************************************************************************
 * dogs.routes.ts
 * -------------------------------------------------------------------------------------------------
 * This file defines the Express Router for managing dog-related endpoints within the API Gateway.
 * It implements secure CRUD operations for dog profiles, adhering to the following key elements:
 *  1) Enhanced authentication with JWT validation (authenticateToken).
 *  2) Role-based access control (authorizeRoles).
 *  3) Comprehensive request validation (validateSchema).
 *  4) Rate limiting with specific configurations for standard or sensitive endpoints.
 *  5) Field-level encryption placeholders for sensitive data (e.g., medicalInfo).
 *  6) Detailed logging and audit placeholders.
 *  7) Field-level masking based on user roles.
 *
 * All business requirements from the technical specification are addressed, including:
 *  - Dog Profile Management (secure CRUD with role checks, input validation, encryption).
 *  - Data Security (encryption placeholders, masked fields, access logging).
 *  - API Security (JWT-based auth, role-based control, rate limiting, request validation).
 *
 * Exports:
 *  - router: The configured Express router for dog endpoints.
 **************************************************************************************************/

// -------------------------------------------------------------------------------------------------
// External Imports (with library version comments)
// -------------------------------------------------------------------------------------------------
import { Router, Request, Response, NextFunction } from 'express'; // express@4.18.2
import * as HttpStatus from 'http-status'; // http-status@1.7.0
import rateLimit from 'express-rate-limit'; // express-rate-limit@7.1.0
import Joi from 'joi'; // joi@17.11.0

// -------------------------------------------------------------------------------------------------
// Internal Imports
// -------------------------------------------------------------------------------------------------
import { authenticateToken, authorizeRoles } from '../middleware/auth.middleware';
import validateSchema from '../middleware/validation.middleware';
import { AuthenticatedRequest } from '../types';

// -------------------------------------------------------------------------------------------------
// Constants & Configuration
// -------------------------------------------------------------------------------------------------

/**
 * dogSchema
 * A Joi schema for validating dog profile payloads with the required fields:
 *  - name       : string, 2-50 chars
 *  - breed      : string, 2-50 chars
 *  - birthDate  : date, cannot be in the future
 *  - medicalInfo: optional object with arrays for conditions, medications, allergies
 *  - active     : boolean, defaults to true
 */
const dogSchema = Joi.object({
  name: Joi.string().required().min(2).max(50),
  breed: Joi.string().required().min(2).max(50),
  birthDate: Joi.date().required().less('now'),
  medicalInfo: Joi.object({
    conditions: Joi.array().items(Joi.string()),
    medications: Joi.array().items(Joi.string()),
    allergies: Joi.array().items(Joi.string()),
    vetContact: Joi.string()
  }).optional(),
  active: Joi.boolean().default(true)
});

/**
 * rateLimitConfig
 * Provides two distinct rate-limiting configurations:
 *  1) standard: 100 requests per 15 minutes
 *  2) sensitive: 50 requests per hour
 * Used to separate normal endpoints from more security-sensitive ones.
 */
const rateLimitConfig = {
  standard: {
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100
  },
  sensitive: {
    windowMs: 60 * 60 * 1000, // 1 hour
    max: 50
  }
};

// -------------------------------------------------------------------------------------------------
// Async Handler (Local Utility)
// -------------------------------------------------------------------------------------------------
/**
 * asyncHandler
 * Wraps an async function in a try/catch to properly route errors to next().
 * This eliminates repetitive try/catch blocks on each route handler.
 *
 * @param {Function} fn - The async route handler function
 * @returns {Function} An Express-compatible function with error handling
 */
function asyncHandler(
  fn: (req: Request, res: Response, next: NextFunction) => Promise<any>
): (req: Request, res: Response, next: NextFunction) => void {
  return (req: Request, res: Response, next: NextFunction): void => {
    fn(req, res, next).catch(next);
  };
}

// -------------------------------------------------------------------------------------------------
// Helper Functions (Placeholders for Encryption, Service Calls, Logging)
// -------------------------------------------------------------------------------------------------

/**
 * encryptMedicalInfo
 * Placeholder function for field-level encryption of sensitive medical details.
 * For production readiness, integrate with a robust encryption mechanism
 * (e.g., AES-256-GCM with secure key management).
 *
 * @param medicalInfo Potentially sensitive data requiring encryption
 * @returns Encrypted representation of the medicalInfo object
 */
function encryptMedicalInfo(medicalInfo: any): string {
  if (!medicalInfo) {
    return '';
  }
  // Placeholder encryption (in reality, use a real cipher library):
  return `ENCRYPTED(${JSON.stringify(medicalInfo)})`;
}

/**
 * createDogInBookingService
 * Placeholder for forwarding dog data to an external or internal booking service.
 * This function would typically involve an HTTP request or queue operation.
 *
 * @param dogData The validated and encrypted dog data to be persisted
 * @returns A promise resolving to the newly created dog record (or relevant information)
 */
async function createDogInBookingService(dogData: any): Promise<any> {
  // In a real implementation, you might call a microservice or database here.
  // For demonstration, we just simulate a created record with an ID.
  return {
    ...dogData,
    id: 'mocked-dog-id',
    createdAt: new Date().toISOString()
  };
}

/**
 * retrieveDogFromBookingService
 * Placeholder for retrieving an existing dog profile from a microservice or database.
 *
 * @param dogId The unique identifier of the dog to retrieve
 * @returns A promise resolving to the dog's current record
 */
async function retrieveDogFromBookingService(dogId: string): Promise<any> {
  // Simulate a retrieved record:
  return {
    id: dogId,
    name: 'Rex',
    breed: 'Golden Retriever',
    birthDate: '2020-01-01',
    medicalInfo: 'ENCRYPTED({"conditions":[],"medications":[],"allergies":[]})',
    ownerId: 'owner-123',
    active: true
  };
}

/**
 * maskMedicalInfo
 * Applies field-level masking for medicalInfo if the requesting user has insufficient privileges.
 * If the user is an owner of this dog or an admin, we can decrypt or display the entire info.
 * If the user is a walker (or any other role), we show partial or no sensitive data.
 *
 * @param dogRecord The dog record containing possibly encrypted medical info
 * @param userRole The role of the authenticated user
 * @param userId   The ID of the authenticated user
 * @returns A dog record with appropriately masked medical information
 */
function maskMedicalInfo(dogRecord: any, userRole: string, userId: string): any {
  // Admin can see everything, owners can see everything, walkers see partial or none:
  if (userRole === 'admin' || (userRole === 'owner' && dogRecord.ownerId === userId)) {
    // In real scenarios, we would decrypt the data. Here we simulate direct usage:
    return {
      ...dogRecord,
      medicalInfo: dogRecord.medicalInfo // Could be decrypted if needed
    };
  }
  // Walker or other roles see only high-level info or an empty object:
  return {
    ...dogRecord,
    medicalInfo: {}
  };
}

/**
 * logAuditEvent
 * Placeholder for logging critical events (e.g., creation or retrieval) to an audit service.
 *
 * @param eventType A label indicating the type of event (e.g., 'DOG_CREATED', 'DOG_RETRIEVED')
 * @param details   Additional context about the event
 */
function logAuditEvent(eventType: string, details: any) {
  // In production, integrate with a logging mechanism or external auditing pipeline.
  // For demonstration, we simply console.log the event.
  // eslint-disable-next-line no-console
  console.log(`[AUDIT] Event: ${eventType}`, details);
}

// -------------------------------------------------------------------------------------------------
// Controllers / Handlers
// -------------------------------------------------------------------------------------------------

/***************************************************************************************************
 * createDog
 * -------------------------------------------------------------------------------------------------
 * Creates a new dog profile with enhanced validation and security checks.
 * Decorators: asyncHandler, validateSchema(dogSchema), rateLimit(rateLimitConfig.sensitive)
 * Steps (reference to specification):
 *   1) Request body is already validated by validateSchema(dogSchema).
 *   2) Extract owner ID from authenticated user object (req.user).
 *   3) Verify user has permission (handled by authorizeRoles middleware).
 *   4) Encrypt sensitive medical information.
 *   5) Forward request to booking service (createDogInBookingService).
 *   6) Log creation event for audit trail.
 *   7) Return created dog profile with masked or minimal sensitive data.
 *
 * @param {AuthenticatedRequest} req - Express request with user payload
 * @param {Response} res - Express response
 * @returns {Promise<Response>} A promise that resolves to the created dog profile
 **************************************************************************************************/
async function createDog(req: AuthenticatedRequest, res: Response): Promise<Response> {
  // Step 2) Extract the owner ID from the authenticated user
  const ownerId = req.user.id;

  // Step 4) Encrypt sensitive fields
  const dogPayload = {
    ...req.body.body, // Because validateSchema merges body, query, params => we nested it
    medicalInfo: encryptMedicalInfo(req.body.body.medicalInfo),
    ownerId
  };

  // Step 5) Forward request to the booking service
  const createdDog = await createDogInBookingService(dogPayload);

  // Step 6) Log creation event
  logAuditEvent('DOG_CREATED', { dogId: createdDog.id, ownerId });

  // Step 7) Return the newly created dog record
  // Masking is optional here. We assume the owner or admin is creating the profile,
  // so we may supply unmasked data back to them. For demonstration, we keep it minimal.
  return res.status(HttpStatus.CREATED).json({
    dog: {
      id: createdDog.id,
      name: createdDog.name,
      breed: createdDog.breed,
      birthDate: createdDog.birthDate,
      active: createdDog.active
      // Omit medicalInfo from immediate creation response or mask if needed
    }
  });
}

/***************************************************************************************************
 * getDog
 * -------------------------------------------------------------------------------------------------
 * Retrieves a dog profile with role-based access control.
 * Decorators: asyncHandler, rateLimit(rateLimitConfig.standard)
 * Steps (reference to specification):
 *   1) Extract dog ID from request params.
 *   2) Confirm user role is valid for access (authorizeRoles in the route).
 *   3) Check ownership or walker assignment (logic below).
 *   4) Retrieve dog data from the booking service.
 *   5) Apply field-level masking based on user role (maskMedicalInfo).
 *   6) Log access for audit trail.
 *   7) Return filtered dog profile.
 *
 * @param {AuthenticatedRequest} req - Express request with user payload
 * @param {Response} res - Express response
 * @returns {Promise<Response>} A promise that resolves to a single dog profile
 **************************************************************************************************/
async function getDog(req: AuthenticatedRequest, res: Response): Promise<Response> {
  // Step 1) Extract dog ID
  const dogId = req.params.id;

  // Step 4) Retrieve dog data
  const dogRecord = await retrieveDogFromBookingService(dogId);

  if (!dogRecord) {
    return res.status(HttpStatus.NOT_FOUND).json({
      error: 'Dog not found'
    });
  }

  // Step 3) Basic ownership or walker assignment check:
  //  - If user is 'owner', ensure dogRecord.ownerId === req.user.id
  //  - If user is 'admin', skip checks
  //  - If user is 'walker', we could check if assigned to this dog's walk, etc.
  // For demonstration, we do a simplified check:
  const userRole = req.user.role;
  if (userRole === 'owner' && dogRecord.ownerId !== req.user.id) {
    return res.status(HttpStatus.FORBIDDEN).json({ error: 'Dog does not belong to this owner' });
  }
  // If role is 'walker', implement additional assignment checks (placeholder).
  // If role is 'admin', skip.

  // Step 5) Apply field-level masking
  const maskedRecord = maskMedicalInfo(dogRecord, userRole, req.user.id);

  // Step 6) Log access
  logAuditEvent('DOG_RETRIEVED', { dogId, accessedBy: req.user.id, role: userRole });

  // Step 7) Return the filtered dog profile
  return res.status(HttpStatus.OK).json({
    dog: maskedRecord
  });
}

/***************************************************************************************************
 * listDogs
 * -------------------------------------------------------------------------------------------------
 * Retrieves a list of dog profiles for the authenticated user. This may be used by owners, walkers,
 * or admins, but the actual filtering logic depends on user role:
 *   - Owner sees only their own dogs.
 *   - Walker might see assigned dogs or an empty list if not assigned.
 *   - Admin can see all dogs.
 * Demonstration uses placeholder logic referencing a hypothetical booking/matching service.
 **************************************************************************************************/
async function listDogs(req: AuthenticatedRequest, res: Response): Promise<Response> {
  const role = req.user.role;
  const userId = req.user.id;

  // Placeholder logic: In reality, retrieve from microservice:
  //  1) If admin, retrieve all dogs
  //  2) If owner, retrieve dogs where dog.ownerId == userId
  //  3) If walker, retrieve assigned dog's IDs, etc.
  // For demonstration, we return a static array with minimal filtering:
  let dogs = [
    { id: 'd1', name: 'Rex', ownerId: 'owner-111', medicalInfo: 'ENCRYPTED({})' },
    { id: 'd2', name: 'Bella', ownerId: 'owner-123', medicalInfo: 'ENCRYPTED({})' }
  ];

  if (role === 'owner') {
    dogs = dogs.filter((d) => d.ownerId === userId);
  } else if (role === 'walker') {
    // Possibly filter by assignment. Demonstration uses an empty array if not assigned:
    // Example placeholder: walker sees no dogs unless specifically assigned
    dogs = [];
  }

  // Mask medical info for non-owners or non-admin roles:
  dogs = dogs.map((dog) => maskMedicalInfo(dog, role, userId));

  logAuditEvent('DOGS_LISTED', { role, userId, dogCount: dogs.length });

  return res.status(HttpStatus.OK).json({ dogs });
}

/***************************************************************************************************
 * updateDog
 * -------------------------------------------------------------------------------------------------
 * Updates an existing dog profile. Typically allowed for owners or admins. This sample includes
 * minimal logic:
 *   1) Validate the request body with dogSchema if needed.
 *   2) Check ownership or admin privileges.
 *   3) Perform update in booking service.
 *   4) Log the update event.
 *   5) Return updated record.
 **************************************************************************************************/
async function updateDog(req: AuthenticatedRequest, res: Response): Promise<Response> {
  const dogId = req.params.id;
  const userId = req.user.id;
  const role = req.user.role;

  // Hypothetical retrieval:
  const dogRecord = await retrieveDogFromBookingService(dogId);
  if (!dogRecord) {
    return res.status(HttpStatus.NOT_FOUND).json({ error: 'Dog not found' });
  }
  if (role === 'owner' && dogRecord.ownerId !== userId) {
    return res.status(HttpStatus.FORBIDDEN).json({ error: 'Unauthorized to update this dog' });
  }

  // Suppose partial updates are allowed. We'll encrypt updated medical info if present:
  const updateData = {
    ...req.body.body,
    medicalInfo: req.body.body.medicalInfo
      ? encryptMedicalInfo(req.body.body.medicalInfo)
      : dogRecord.medicalInfo
  };

  // Simulate an update call:
  const updated = {
    ...dogRecord,
    ...updateData
  };

  logAuditEvent('DOG_UPDATED', { dogId, updatedBy: userId });

  // Return updated record (masked if needed):
  const masked = maskMedicalInfo(updated, role, userId);
  return res.status(HttpStatus.OK).json({ dog: masked });
}

/***************************************************************************************************
 * deleteDog
 * -------------------------------------------------------------------------------------------------
 * Deletes an existing dog profile. Typically reserved for owners or admins. Demonstration includes:
 *   1) Confirm dog exists.
 *   2) Check ownership or admin privileges.
 *   3) Execute deletion in booking service (placeholder).
 *   4) Log the delete event.
 *   5) Return success status code.
 **************************************************************************************************/
async function deleteDog(req: AuthenticatedRequest, res: Response): Promise<Response> {
  const dogId = req.params.id;
  const userId = req.user.id;
  const role = req.user.role;

  const dogRecord = await retrieveDogFromBookingService(dogId);
  if (!dogRecord) {
    return res.status(HttpStatus.NOT_FOUND).json({ error: 'Dog not found' });
  }
  if (role === 'owner' && dogRecord.ownerId !== userId) {
    return res.status(HttpStatus.FORBIDDEN).json({ error: 'Unauthorized to delete this dog' });
  }

  // Placeholder for actual delete call:
  logAuditEvent('DOG_DELETED', { dogId, deletedBy: userId });

  return res.status(HttpStatus.NO_CONTENT).send();
}

// -------------------------------------------------------------------------------------------------
// Router Definition
// -------------------------------------------------------------------------------------------------
export const router = Router();

/**
 * POST /dogs
 * Creates a new dog profile (Owner or Admin roles).
 * Middlewares:
 *  - rateLimit(rateLimitConfig.sensitive) for sensitive creation endpoint
 *  - authenticateToken for JWT validation
 *  - authorizeRoles(['owner','admin']) for role-based control
 *  - validateSchema(dogSchema, { ... }) for input validation
 *  - asyncHandler(createDog) to handle async errors
 */
router.post(
  '/dogs',
  rateLimit(rateLimitConfig.sensitive),
  authenticateToken,
  authorizeRoles(['owner', 'admin']),
  validateSchema(dogSchema, {
    abortEarly: false,
    stripUnknown: true
  }),
  asyncHandler(createDog)
);

/**
 * GET /dogs
 * Lists dog profiles for the requesting user. The logic filters results based on role.
 * Middlewares:
 *  - rateLimit(rateLimitConfig.standard)
 *  - authenticateToken
 *  - authorizeRoles(['owner','walker','admin'])
 *  - asyncHandler(listDogs)
 */
router.get(
  '/dogs',
  rateLimit(rateLimitConfig.standard),
  authenticateToken,
  authorizeRoles(['owner', 'walker', 'admin']),
  asyncHandler(listDogs)
);

/**
 * GET /dogs/:id
 * Retrieves a specific dog profile with field-level masking for non-owners/admins.
 * Middlewares:
 *  - rateLimit(rateLimitConfig.standard)
 *  - authenticateToken
 *  - authorizeRoles(['owner','walker','admin'])
 *  - asyncHandler(getDog)
 */
router.get(
  '/dogs/:id',
  rateLimit(rateLimitConfig.standard),
  authenticateToken,
  authorizeRoles(['owner', 'walker', 'admin']),
  asyncHandler(getDog)
);

/**
 * PUT /dogs/:id
 * Updates an existing dog profile. Reserved for owners or admins.
 * Middlewares:
 *  - rateLimit(rateLimitConfig.sensitive)
 *  - authenticateToken
 *  - authorizeRoles(['owner','admin'])
 *  - validateSchema(dogSchema, { ... }) to ensure partial or full updates are valid
 *  - asyncHandler(updateDog)
 */
router.put(
  '/dogs/:id',
  rateLimit(rateLimitConfig.sensitive),
  authenticateToken,
  authorizeRoles(['owner', 'admin']),
  validateSchema(dogSchema, {
    abortEarly: false,
    stripUnknown: true,
    // In many update scenarios, you might allowUnknown or remove required checks, but here we keep it strict.
  }),
  asyncHandler(updateDog)
);

/**
 * DELETE /dogs/:id
 * Deletes an existing dog profile. Allowed for owners or admins.
 * Middlewares:
 *  - rateLimit(rateLimitConfig.sensitive)
 *  - authenticateToken
 *  - authorizeRoles(['owner','admin'])
 *  - asyncHandler(deleteDog)
 */
router.delete(
  '/dogs/:id',
  rateLimit(rateLimitConfig.sensitive),
  authenticateToken,
  authorizeRoles(['owner', 'admin']),
  asyncHandler(deleteDog)
);