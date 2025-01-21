from dataclasses import dataclass, field
from enum import Enum
from datetime import datetime
from typing import Dict, Any, Optional
from uuid import uuid4

class NotificationType(Enum):
    """
    Enum defining supported notification types including
    real-time and emergency notifications.
    """
    WALK_SCHEDULED = "WALK_SCHEDULED"
    WALK_STARTED = "WALK_STARTED"
    WALK_COMPLETED = "WALK_COMPLETED"
    WALK_CANCELLED = "WALK_CANCELLED"
    PAYMENT_RECEIVED = "PAYMENT_RECEIVED"
    PAYMENT_FAILED = "PAYMENT_FAILED"
    WALKER_ASSIGNED = "WALKER_ASSIGNED"
    EMERGENCY_ALERT = "EMERGENCY_ALERT"
    LOCATION_UPDATE = "LOCATION_UPDATE"
    REVIEW_REQUEST = "REVIEW_REQUEST"


class NotificationStatus(Enum):
    """
    Enum defining possible notification delivery statuses
    with retry support.
    """
    PENDING = "PENDING"
    SENT = "SENT"
    DELIVERED = "DELIVERED"
    FAILED = "FAILED"
    RETRYING = "RETRYING"


class NotificationChannel(Enum):
    """
    Enum defining supported notification delivery channels
    (email, push, and SMS).
    """
    EMAIL = "EMAIL"
    PUSH = "PUSH"
    SMS = "SMS"


@dataclass(slots=True, frozen=False)
class Notification:
    """
    Core notification data model class with enhanced retry and metadata support.
    """

    id: str = field(init=False)
    recipient_id: str = field(init=False)
    type: NotificationType = field(init=False)
    channel: NotificationChannel = field(init=False)
    status: NotificationStatus = field(init=False)
    content: Dict[str, Any] = field(init=False)
    metadata: Dict[str, Any] = field(init=False)
    created_at: datetime = field(init=False)
    updated_at: datetime = field(init=False)
    retry_count: int = field(init=False)
    max_retries: int = field(init=False)

    def __init__(
        self,
        recipient_id: str,
        type: NotificationType,
        channel: NotificationChannel,
        content: Dict[str, Any],
        metadata: Optional[Dict[str, Any]] = None
    ) -> None:
        """
        Initializes a new notification instance with default values
        and channel-specific settings.
        Steps:
         1. Generate unique notification ID using UUID4.
         2. Set initial notification status to PENDING.
         3. Initialize created_at and updated_at timestamps.
         4. Set retry_count to 0.
         5. Set max_retries based on channel:
            - EMAIL: 3
            - PUSH: 2
            - SMS: 1
         6. Initialize empty metadata dict if None provided.
         7. Validate content structure based on notification type.
        """
        object.__setattr__(self, 'id', str(uuid4()))
        object.__setattr__(self, 'recipient_id', recipient_id)
        object.__setattr__(self, 'type', type)
        object.__setattr__(self, 'channel', channel)
        object.__setattr__(self, 'status', NotificationStatus.PENDING)
        now = datetime.utcnow()
        object.__setattr__(self, 'created_at', now)
        object.__setattr__(self, 'updated_at', now)
        object.__setattr__(self, 'retry_count', 0)

        # Determine max retries based on channel
        if channel == NotificationChannel.EMAIL:
            object.__setattr__(self, 'max_retries', 3)
        elif channel == NotificationChannel.PUSH:
            object.__setattr__(self, 'max_retries', 2)
        else:
            object.__setattr__(self, 'max_retries', 1)

        if metadata is None:
            metadata = {}
        object.__setattr__(self, 'metadata', metadata)

        # Validate content structure based on notification type (minimal example)
        self._validate_content(content, type)
        object.__setattr__(self, 'content', content)

    def update_status(self, new_status: NotificationStatus) -> None:
        """
        Updates notification delivery status with timestamp tracking.
        Steps:
         1. Validate status transition is allowed.
         2. Update status field.
         3. Update updated_at timestamp.
         4. Log status change for monitoring.
        """
        allowed_transitions = {
            NotificationStatus.PENDING: [
                NotificationStatus.SENT, NotificationStatus.FAILED, NotificationStatus.RETRYING
            ],
            NotificationStatus.SENT: [
                NotificationStatus.DELIVERED, NotificationStatus.FAILED, NotificationStatus.RETRYING
            ],
            NotificationStatus.DELIVERED: [],
            NotificationStatus.FAILED: [
                NotificationStatus.RETRYING
            ],
            NotificationStatus.RETRYING: [
                NotificationStatus.SENT, NotificationStatus.FAILED
            ],
        }

        if new_status not in allowed_transitions[self.status]:
            raise ValueError(
                f"Invalid status transition from {self.status.name} to {new_status.name}."
            )

        self.status = new_status
        self.updated_at = datetime.utcnow()

        # TODO: Integrate with a logging/monitoring system for status changes

    def increment_retry(self) -> bool:
        """
        Increments retry counter with backoff calculation.
        Steps:
         1. Increment retry counter.
         2. Update updated_at timestamp.
         3. Calculate exponential backoff delay.
         4. Update metadata with retry information.
         5. Return True if max retries reached.
        """
        self.retry_count += 1
        self.updated_at = datetime.utcnow()

        backoff_seconds = 5 * (2 ** (self.retry_count - 1))
        self.metadata["last_retry_backoff_seconds"] = backoff_seconds

        # TODO: Actual scheduling of next retry could be handled externally

        return self.retry_count >= self.max_retries

    def to_dict(self) -> Dict[str, Any]:
        """
        Converts notification to dictionary format for serialization.
        Steps:
         1. Convert all fields to dictionary format.
         2. Convert enums to string values.
         3. Format timestamps to ISO format.
         4. Include retry information.
         5. Sanitize sensitive data in content/metadata if present.
        """
        result = {
            "id": self.id,
            "recipient_id": self.recipient_id,
            "type": self.type.name,
            "channel": self.channel.name,
            "status": self.status.name,
            "content": self._sanitize_data(dict(self.content)),
            "metadata": self._sanitize_data(dict(self.metadata)),
            "created_at": self.created_at.isoformat(),
            "updated_at": self.updated_at.isoformat(),
            "retry_count": self.retry_count,
            "max_retries": self.max_retries,
        }
        return result

    def _validate_content(self, content: Dict[str, Any], ntype: NotificationType) -> None:
        """
        Basic content validation check based on notification type.
        Extend or modify as needed for production usage.
        """
        if ntype == NotificationType.LOCATION_UPDATE and "location" not in content:
            raise ValueError("Content must include 'location' for LOCATION_UPDATE notifications.")
        if ntype == NotificationType.EMERGENCY_ALERT and "alert_level" not in content:
            raise ValueError("Content must include 'alert_level' for EMERGENCY_ALERT notifications.")

    def _sanitize_data(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Removes sensitive fields from the given dictionary.
        Extend with additional fields or logic as needed.
        """
        if "password" in data:
            del data["password"]
        if "token" in data:
            del data["token"]
        return data