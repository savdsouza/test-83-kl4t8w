package utils

import (
	// math provides mathematical functions (go1.21) used in the haversine formula and trigonometric operations
	"math"
	// time provides functionality for durations and time-based calculations (go1.21)
	"time"

	// models provides the Location struct used for GPS coordinate representations
	"src/backend/tracking-service/internal/models"
	"fmt"
)

// EarthRadius is Earth's mean radius in kilometers used by the haversine formula.
const EarthRadius float64 = 6371.0

// MinDistanceThreshold is the minimum distance (in km) to consider valid movement, filtering out GPS noise.
const MinDistanceThreshold float64 = 0.001

// MaxSpeedThreshold is the maximum realistic speed (in km/h) for dog walking. Any higher indicates invalid movement.
const MaxSpeedThreshold float64 = 35.0

// CalculateDistance computes the precise distance between two GPS coordinates using the haversine formula.
// It returns the distance in kilometers rounded to six decimal places, or an error if the coordinates
// are invalid or the calculation process fails. A minimum distance threshold is applied to mitigate noise.
//
// Steps:
//  1. Validate the input Location data using the models.Location validation logic.
//  2. Convert latitude and longitude from degrees to radians.
//  3. Calculate deltas (dLat and dLon) and apply the haversine formula:
//       a = sin²(dLat/2) + cos(lat1) * cos(lat2) * sin²(dLon/2)
//       distance = 2 * EarthRadius * arcsin( sqrt(a) )
//  4. If the resulting distance is below MinDistanceThreshold, return 0.0 to filter out noise.
//  5. Round the final result to six decimal places and return.
func CalculateDistance(point1 *models.Location, point2 *models.Location) (float64, error) {
	// Validate point1
	if err := point1.Validate(); err != nil {
		return 0.0, fmt.Errorf("calculateDistance error: invalid point1: %w", err)
	}
	// Validate point2
	if err := point2.Validate(); err != nil {
		return 0.0, fmt.Errorf("calculateDistance error: invalid point2: %w", err)
	}

	// Convert degrees to radians
	lat1Rad := point1.Latitude * (math.Pi / 180.0)
	lon1Rad := point1.Longitude * (math.Pi / 180.0)
	lat2Rad := point2.Latitude * (math.Pi / 180.0)
	lon2Rad := point2.Longitude * (math.Pi / 180.0)

	// Compute deltas
	dLat := lat2Rad - lat1Rad
	dLon := lon2Rad - lon1Rad

	// Apply haversine formula
	a := math.Sin(dLat/2)*math.Sin(dLat/2) +
		math.Cos(lat1Rad)*math.Cos(lat2Rad)*math.Sin(dLon/2)*math.Sin(dLon/2)
	c := 2 * math.Asin(math.Sqrt(a))
	distance := EarthRadius * c

	// Filter out minimal distances caused by noise
	if distance < MinDistanceThreshold {
		return 0.0, nil
	}

	// Round to 6 decimal places
	distance = math.Round(distance*1e6) / 1e6

	return distance, nil
}

// CalculateRouteDistance totals the distance covered by a series of GPS coordinates,
// ensuring valid movements and filtering out invalid or noise-based segments.
//
// Steps:
//  1. Check that the input slice has at least two points; if not, returns an error.
//  2. Initialize a total distance accumulator.
//  3. Iterate through each consecutive pair of locations:
//       a) Validate both coordinates.
//       b) Calculate the distance using CalculateDistance.
//       c) If the distance is above MinDistanceThreshold, accumulate it.
//  4. Round the final total route distance to six decimal places and return.
func CalculateRouteDistance(points []*models.Location) (float64, error) {
	if len(points) < 2 {
		return 0.0, fmt.Errorf("calculateRouteDistance error: at least two points are required")
	}

	var totalDistance float64
	for i := 1; i < len(points); i++ {
		dist, err := CalculateDistance(points[i-1], points[i])
		if err != nil {
			return 0.0, fmt.Errorf("calculateRouteDistance error: %w", err)
		}
		if dist >= MinDistanceThreshold {
			totalDistance += dist
		}
	}

	// Round the total distance to 6 decimal places
	totalDistance = math.Round(totalDistance*1e6) / 1e6
	return totalDistance, nil
}

// IsValidMovement checks whether movement between two GPS points is realistic
// based on speed thresholds, time difference, and minimum distance considerations.
//
// Steps:
//  1. Calculate the distance between the points using CalculateDistance.
//  2. Check if distance exceeds the MinDistanceThreshold to ensure it's not purely noise.
//  3. Calculate the speed in km/h from the distance and the provided time difference.
//  4. If speed exceeds MaxSpeedThreshold, return false to indicate an unrealistic movement.
//  5. Ensure the time difference is positive; otherwise, it's invalid data.
//  6. Return true if all checks pass, or false with an explanatory error if any validation fails.
func IsValidMovement(point1 *models.Location, point2 *models.Location, timeDiff time.Duration) (bool, error) {
	// Calculate the distance using the core haversine-based function
	distance, err := CalculateDistance(point1, point2)
	if err != nil {
		return false, fmt.Errorf("isValidMovement error: distance calculation failed: %w", err)
	}

	// Ensure the distance surpasses the minimal threshold for valid movement
	if distance < MinDistanceThreshold {
		return false, nil
	}

	// Verify that the time difference is positive to avoid division by zero or negative speed
	if timeDiff <= 0 {
		return false, fmt.Errorf("isValidMovement error: invalid time difference (<= 0)")
	}

	// Compute speed as distance (km) over timeDiff (hours)
	speed := distance / timeDiff.Hours()

	// Check if the computed speed is greater than the permissible threshold
	if speed > MaxSpeedThreshold {
		return false, nil
	}

	// If all conditions are satisfied, the movement is deemed valid
	return true, nil
}