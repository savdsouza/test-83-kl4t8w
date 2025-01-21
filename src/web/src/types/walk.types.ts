/**
 * ------------------------------------------------------------------------
 * Type Definitions for Walk-Related Data Structures
 * ------------------------------------------------------------------------
 * This file provides comprehensive TypeScript interfaces and types for all
 * walk-related operations, spanning real-time GPS tracking, photo sharing,
 * status updates, route information, and booking workflows. It integrates with
 * user and dog entities for owners, walkers, and respective pets.
 *
 * Core Requirements Addressed:
 * 1) Service Execution: Ensures coverage of GPS tracking, photo capturing,
 *    status updates, and route metrics during each walk session.
 * 2) Booking System: Supports real-time scheduling, matching, and overall
 *    booking life cycle management for walk requests.
 *
 * ------------------------------------------------------------------------
 */

import { Status, Coordinates } from './common.types'; // Internal import for status & coordinates
import { User } from './user.types';                  // Internal import for user reference
import { Dog } from './dog.types';                    // Internal import for dog reference

/**
 * Enum describing valid status states for a walk session.
 * Each entry clarifies a potential phase or outcome
 * within a walk's life cycle, from initial request
 * to final completion or cancellation.
 */
export enum WalkStatus {
  /**
   * Indicates that the walk has been requested by an owner
   * but not yet accepted by a walker.
   */
  REQUESTED = 'REQUESTED',

  /**
   * Denotes that a walker has accepted the walk request,
   * awaiting commencement.
   */
  ACCEPTED = 'ACCEPTED',

  /**
   * Reflects an ongoing walk, where the walker is actively
   * with the dog, sending updates and tracking route data.
   */
  IN_PROGRESS = 'IN_PROGRESS',

  /**
   * Signifies that the walk session was successfully finished,
   * and all immediate tasks have concluded.
   */
  COMPLETED = 'COMPLETED',

  /**
   * Implies that the walk session has been canceled by either
   * the owner or the walker prior to completion.
   */
  CANCELLED = 'CANCELLED',
}

/**
 * Interface representing a single photo captured during a walk.
 * Provides necessary fields for photo identification, hosting
 * location, and optional descriptive captions. Encourages
 * real-time sharing and archiving of photos in the system.
 */
export interface WalkPhoto {
  /**
   * Unique system-generated identifier for this photo.
   */
  id: string;

  /**
   * References the walk session to which this photo belongs.
   */
  walkId: string;

  /**
   * A publicly accessible or secured URL where the photo
   * is stored. Varies by storage provider.
   */
  url: string;

  /**
   * Timestamp indicating when the photo was captured.
   */
  timestamp: Date;

  /**
   * Geographic location of the photo capture, enabling
   * in-depth route and memory-trail features.
   */
  coordinates: Coordinates;

  /**
   * Optional textual description or caption accompanying the photo.
   */
  caption: string;
}

/**
 * Interface for real-time location updates sent during walks.
 * Each update records positional data, time of capture, and
 * additional metrics like accuracy or speed. Facilitates
 * mapping and progress tracking in the client.
 */
export interface LocationUpdate {
  /**
   * ID referencing the active walk session for which this
   * location update applies.
   */
  walkId: string;

  /**
   * Current latitude/longitude measurement of the walker
   * and dog during the session.
   */
  coordinates: Coordinates;

  /**
   * Timestamp for when this location was recorded, ensuring
   * chronological reconstruction of the walk route.
   */
  timestamp: Date;

  /**
   * Estimated accuracy in meters of the reported coordinates.
   * Lower values imply higher positional precision.
   */
  accuracy: number;

  /**
   * Measured speed in meters per second, aiding in
   * route analytics and pace calculations.
   */
  speed: number;
}

/**
 * Interface holding route details of a walk session for
 * post-walk metrics and visualization. Captures route
 * geometry, computed distance, and relevant endpoints.
 */
export interface WalkRoute {
  /**
   * Unique identifier of the walk session whose route is recorded.
   */
  walkId: string;

  /**
   * Ordered collection of geographic coordinates representing
   * the path taken during the walk.
   */
  points: Coordinates[];

  /**
   * Total distance (in meters) covered during the walk.
   */
  distance: number;

  /**
   * Duration (in minutes) of the walk, capturing the total
   * elapsed time from start to end.
   */
  duration: number;

  /**
   * Coordinates indicating where the walk or route started.
   */
  startLocation: Coordinates;

  /**
   * Coordinates indicating where the walk or route concluded.
   */
  endLocation: Coordinates;
}

/**
 * Primary interface describing a walk session from creation
 * through completion. Encapsulates essential relationships,
 * times, metrics, route data, and feedback components.
 */
export interface Walk {
  /**
   * Unique identifier assigned to this walk session.
   */
  id: string;

  /**
   * Identifier of the user acting as the dog owner
   * for this specific walk request.
   */
  ownerId: string;

  /**
   * Identifier of the user serving as the walker
   * for this session, if accepted.
   */
  walkerId: string;

  /**
   * Identifier linking to the dog participating
   * in the walk, ensuring correct pet association.
   */
  dogId: string;

  /**
   * High-level status indicator of the walk, referencing
   * the WalkStatus enum states.
   */
  status: WalkStatus;

  /**
   * Date/time when the walk is scheduled to begin or actually began.
   */
  startTime: Date;

  /**
   * Date/time denoting when the walk concluded or is anticipated to end.
   */
  endTime: Date;

  /**
   * Duration (in minutes) of the walk. May be user-defined or
   * computed upon completion based on actual timestamps.
   */
  duration: number;

  /**
   * Cost or fee (in the application's default currency) associated
   * with this walk, derived from the service's pricing mechanism.
   */
  price: number;

  /**
   * Route details capturing path, distance, and location data
   * for the walk session, facilitating analytics and logs.
   */
  route: WalkRoute;

  /**
   * Array of photos taken during the walk, optionally stored
   * to document the session or share with the owner.
   */
  photos: WalkPhoto[];

  /**
   * Numeric rating assigned by the owner upon walk completion,
   * reflecting the walker's performance or dog's experience.
   */
  rating: number;

  /**
   * Owner-submitted written review describing the walk experience,
   * complementing the numeric rating.
   */
  review: string;

  /**
   * Additional notes relevant to the walk, potentially capturing
   * special considerations or updates not included elsewhere.
   */
  notes: string;

  /**
   * Emergency contact information (phone number or email),
   * available for urgent situations during the walk.
   */
  emergencyContact: string;

  /**
   * Timestamp for when this walk record was created in the system.
   */
  createdAt: Date;

  /**
   * Timestamp reflecting the most recent revision or update to
   * this walk record.
   */
  updatedAt: Date;
}

/**
 * Type representing the payload required to create a new walk session.
 * Excludes fields automatically generated (e.g., id, status, route, photos)
 * or populated upon finalization (rating, review, timestamps).
 */
export type CreateWalkRequest = Omit<
  Walk,
  'id' | 'status' | 'route' | 'photos' | 'rating' | 'review' | 'createdAt' | 'updatedAt'
>;

/**
 * Type representing any partial update to a walk session, enabling
 * flexible updates for fields such as time, price, or notes without
 * having to provide the entire structure.
 */
export type UpdateWalkRequest = Partial<CreateWalkRequest>;