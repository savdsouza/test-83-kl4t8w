/**
 * This file provides comprehensive TypeScript type definitions and interfaces
 * for dog-related data structures in the web application. It includes enums,
 * interfaces, and types that facilitate robust type safety for pet profile
 * management, medical details, and update operations.
 */

import { Status } from './common.types';

/**
 * Enumerates the standardized categorization of dog sizes.
 * Each value clearly indicates the approximate size category
 * of a dog, guiding UI displays and potential logic for matching
 * walk or care requirements.
 */
export enum DogSize {
  /**
   * Represents dogs weighing under 20 lbs (9 kg).
   */
  SMALL = 'SMALL',

  /**
   * Represents dogs weighing between 20 lbs (9 kg) and 50 lbs (23 kg).
   */
  MEDIUM = 'MEDIUM',

  /**
   * Represents dogs weighing between 50 lbs (23 kg) and 90 lbs (41 kg).
   */
  LARGE = 'LARGE',

  /**
   * Represents dogs weighing over 90 lbs (41 kg).
   */
  EXTRA_LARGE = 'EXTRA_LARGE',
}

/**
 * Provides comprehensive information about a particular
 * dog breed, including its unique identifier, human-readable
 * name, size category, general traits, and an indicator for
 * how much exercise the breed typically needs.
 */
export interface DogBreed {
  /**
   * Unique ID of the breed entry in the system, ensuring each breed
   * can be distinctly identified and referenced.
   */
  id: string;

  /**
   * The human-readable breed name (e.g., "Golden Retriever", "Bulldog").
   */
  name: string;

  /**
   * The size category for this breed, mapped to the DogSize enum
   * for better type safety and logic.
   */
  size: DogSize;

  /**
   * A list of characteristic strings that describe typical traits
   * of the breed (e.g., "Friendly", "Active", "Calm").
   */
  characteristics: string[];

  /**
   * A numeric indicator (e.g., a scale from 1 to 10) describing
   * how much exercise is generally recommended for this breed.
   */
  exerciseNeeds: number;
}

/**
 * Captures all relevant medical-related data for a dog.
 * This includes allergies, medications, underlying conditions,
 * veterinary contact information, last checkup date, and
 * vaccination records.
 */
export interface MedicalInfo {
  /**
   * A list of known allergens affecting the dog, such as certain foods
   * or environmental triggers (e.g., pollen, chicken).
   */
  allergies: string[];

  /**
   * A collection of medications currently prescribed or needed by the dog,
   * including dosage and schedule details.
   */
  medications: Array<{
    /**
     * Common or trade name of the medication.
     */
    name: string;
    /**
     * The exact dose the dog must take (e.g., "5mg", "1 tablet").
     */
    dosage: string;
    /**
     * The schedule or frequency with which the dog must receive the medication.
     */
    schedule: string;
  }>;

  /**
   * Details for known health conditions, including severity
   * and any relevant notes.
   */
  conditions: Array<{
    /**
     * The name or type of the condition (e.g., "Arthritis", "Anxiety").
     */
    name: string;
    /**
     * The severity of the condition (e.g., "mild", "moderate", "severe").
     */
    severity: string;
    /**
     * Additional notes or observations regarding the condition.
     */
    notes: string;
  }>;

  /**
   * Information about the primary veterinarian, supporting quick
   * reference during emergencies or routine checkups.
   */
  vetContact: {
    /**
     * Name of the veterinary professional, clinic, or hospital.
     */
    name: string;
    /**
     * Primary contact phone number for the vet.
     */
    phone: string;
    /**
     * Email address for the vet, if available.
     */
    email: string;
    /**
     * Physical address of the veterinarian’s clinic or hospital.
     */
    address: string;
  };

  /**
   * The date (ISO 8601 string) of the dog's most recent checkup.
   * Used for scheduling future appointments and medical follow-ups.
   */
  lastCheckup: string;

  /**
   * Documentation of the dog’s vaccination history. Each record specifies
   * the name of the vaccine, administration date, and the next due date.
   */
  vaccinations: Array<{
    /**
     * Name of the vaccine (e.g., "Rabies", "Distemper").
     */
    name: string;
    /**
     * ISO 8601 date string representing when the vaccine was administered.
     */
    date: string;
    /**
     * ISO 8601 date string representing the recommended next date
     * for this vaccination.
     */
    nextDue: string;
  }>;
}

/**
 * Represents a complete dog profile in the system, combining dog identity,
 * breed, birthdate, medical data, status, weight tracking, special care
 * instructions, walking preferences, and metadata for auditing.
 */
export interface Dog {
  /**
   * Unique, system-generated ID that identifies the dog profile.
   */
  id: string;

  /**
   * The ID of the owner or user to whom the dog belongs.
   */
  ownerId: string;

  /**
   * The dog's given name, provided by the owner.
   */
  name: string;

  /**
   * The breed information associated with the dog, referencing the DogBreed interface.
   */
  breed: DogBreed;

  /**
   * The date of birth for this dog (ISO 8601 string). Used to calculate age
   * and inform certain care instructions.
   */
  birthDate: string;

  /**
   * The object containing all relevant medical information for this dog.
   */
  medicalInfo: MedicalInfo;

  /**
   * The current status of the dog's profile (e.g., ACTIVE, INACTIVE),
   * pulled from the shared Status enum.
   */
  status: Status;

  /**
   * Optional URL reference to the dog’s profile image or avatar.
   */
  profileImageUrl: string | null;

  /**
   * Reflects the dog's current weight and weight history records.
   * Useful for tracking trends over time and informing care decisions.
   */
  weight: {
    /**
     * The dog's current weight in pounds or kilograms (units determined by external context).
     */
    current: number;
    /**
     * A historical log of the dog's weights over time, including the date of measurement.
     */
    history: Array<{
      /**
       * ISO 8601 date string for when this weight was recorded.
       */
      date: string;
      /**
       * The dog’s weight at that date in the same units as 'current'.
       */
      weight: number;
    }>;
  };

  /**
   * A list of special or custom instructions that may be relevant for
   * caregivers or walkers (e.g., "Must avoid other dogs", "Needs extra rest").
   */
  specialInstructions: Array<{
    /**
     * High-level category or label for the instruction (e.g., "Feeding", "Behavior").
     */
    category: string;
    /**
     * The detailed instruction text that should be clearly communicated.
     */
    instructions: string;
    /**
     * A numeric priority indicating how critical or urgent this instruction may be.
     */
    priority: number;
  }>;

  /**
   * Provides parameters for the dog's walking routines, indicating duration,
   * preferred intensity (walk vs. jog), and any constraints or restrictions
   * for the walk (e.g., "No off-leash", "Avoid busy roads").
   */
  walkingPreferences: {
    /**
     * The recommended length of time, in minutes, for each walk session.
     */
    duration: number;
    /**
     * A textual representation of how rigorous the walk session should be
     * (e.g., "moderate", "slow", "energetic").
     */
    intensity: string;
    /**
     * A collection of restrictions (e.g., "avoid dog parks", "must remain on leash").
     */
    restrictions: string[];
  };

  /**
   * ISO 8601 date string specifying when this dog profile was last updated.
   * Used for concurrency checks, synchronization, and auditing changes.
   */
  lastUpdated: string;

  /**
   * ISO 8601 date string specifying when this dog profile was created.
   * Useful for chronological sorting and historical reference.
   */
  createdAt: string;
}

/**
 * Defines the type payload for creating a new dog profile in the system.
 * It omits server-generated fields such as 'id', 'lastUpdated', and 'createdAt',
 * which are provisioned automatically on the backend.
 */
export type CreateDogRequest = Omit<Dog, 'id' | 'lastUpdated' | 'createdAt'>;

/**
 * Specifies a type for updating an existing dog profile.
 * It marks all properties from CreateDogRequest as optional,
 * enabling partial updates of only the changed fields.
 */
export type UpdateDogRequest = Partial<CreateDogRequest>;