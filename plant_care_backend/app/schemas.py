from __future__ import annotations

from datetime import date, datetime
from typing import Any

from pydantic import BaseModel, EmailStr, Field


class ApiMessage(BaseModel):
    message: str


class UserPublic(BaseModel):
    id: int
    name: str
    email: EmailStr
    points: int = 0
    phone: str | None = None
    birthday: date | None = None


class AuthRegisterRequest(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    phone: str | None = Field(default=None, max_length=50)
    birthday: str | None = None


class AuthLoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=128)


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    access_expires_at: datetime


class AuthResponse(BaseModel):
    user: UserPublic
    tokens: TokenPair


class TokenRefreshRequest(BaseModel):
    refresh_token: str


class UserUpdateRequest(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=100)
    email: EmailStr | None = None
    phone: str | None = Field(default=None, max_length=50)
    birthday: str | None = None


class ChangePasswordRequest(BaseModel):
    old_password: str = Field(min_length=1, max_length=128)
    new_password: str = Field(min_length=8, max_length=128)


class DeleteAccountRequest(BaseModel):
    password: str = Field(min_length=1, max_length=128)


class AnnouncementItem(BaseModel):
    title: str
    date: str
    content: str


class AnnouncementListResponse(BaseModel):
    results: list[AnnouncementItem]


class PlantTaskItem(BaseModel):
    content: str
    state: bool


class PlantPublic(BaseModel):
    uuid: str
    plant_variety: str
    plant_name: str
    plant_state: str
    setup_time: str
    initialization: str | None = None
    task: dict[str, PlantTaskItem] | None = None


class PlantListResponse(BaseModel):
    results: list[PlantPublic]


class PlantSummary(BaseModel):
    uuid: str
    plant_variety: str
    plant_name: str
    plant_state: str
    setup_time: str
    initialization: str | None = None


class PlantSummaryListResponse(BaseModel):
    results: list[PlantSummary]


class PlantDetail(PlantSummary):
    today_state: str | None = None
    last_watering_time: str | None = None
    task: dict[str, PlantTaskItem] | None = None


class PlantGetInfoRequest(BaseModel):
    email: EmailStr | None = None



class PlantCreateRequest(BaseModel):
    plant_variety: str
    plant_name: str
    plant_state: str
    setup_time: str
    email: EmailStr | None = None


class PlantUpdateRequest(BaseModel):
    uuid: str
    plant_variety: str
    plant_name: str
    plant_state: str
    setup_time: str
    email: EmailStr | None = None


class PlantDeleteRequest(BaseModel):
    uuid: str
    email: EmailStr | None = None


class PlantInitializeRequest(BaseModel):
    uuid: str
    email: EmailStr | None = None
    today_state: str | None = None
    last_watering_time: str | None = None


class PlantUpdateTaskRequest(BaseModel):
    uuid: str
    email: EmailStr | None = None
    task: Any


class AiGenerateTasksRequest(BaseModel):
    plant_variety: str
    plant_state: str
    today_state: str | None = None
    last_watering_time: str | None = None
    locale: str = "en-US"
    count: int = Field(default=6, ge=1, le=12)


class AiGenerateTasksResponse(BaseModel):
    tasks: dict[str, PlantTaskItem]
