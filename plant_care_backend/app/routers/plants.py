from __future__ import annotations

import json
import uuid as uuidlib
from datetime import UTC, date, datetime
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.deps import get_current_user
from app.models import Plant, User
from app.routers.ai import generate_tasks as ai_generate_tasks
from app.schemas import (
    ApiMessage,
    AiGenerateTasksRequest,
    PlantCreateRequest,
    PlantDeleteRequest,
    PlantDetail,
    PlantGetInfoRequest,
    PlantInitializeRequest,
    PlantListResponse,
    PlantPublic,
    PlantSummary,
    PlantSummaryListResponse,
    PlantUpdateRequest,
    PlantUpdateTaskRequest,
)
from app.utils.datetime import parse_ymd, parse_ymdhms

router = APIRouter()


def _fmt_ymd(d: date) -> str:
    return d.strftime("%Y%m%d")


def _fmt_ymdhms(dt: datetime) -> str:
    v = dt
    if v.tzinfo is None:
        v = v.replace(tzinfo=UTC)
    return v.astimezone(UTC).strftime("%Y%m%d%H%M%S")


def _is_true(v: Any) -> bool:
    if v is True:
        return True
    if isinstance(v, str):
        return v.strip().lower() == "true"
    return False


async def _generate_tasks_for_plant(p: Plant) -> dict[str, dict[str, Any]]:
    req = AiGenerateTasksRequest(
        plant_variety=p.plant_variety,
        plant_state=p.plant_state,
        today_state=p.today_state,
        last_watering_time=_fmt_ymdhms(p.last_watering_time) if p.last_watering_time else None,
        locale="en-US",
        count=5,
    )
    res = await ai_generate_tasks(req)
    return {k: {"content": v.content, "state": bool(v.state)} for k, v in res.tasks.items()}


def _decode_task(value: Any) -> dict | None:
    if value is None:
        return None
    if isinstance(value, dict):
        return value
    if isinstance(value, str):
        s = value.strip()
        try:
            decoded = json.loads(s)
        except json.JSONDecodeError:
            return None
        if isinstance(decoded, str):
            try:
                decoded = json.loads(decoded)
            except json.JSONDecodeError:
                return None
        return decoded if isinstance(decoded, dict) else None
    return None


def _enforce_email(user: User, email: str | None) -> None:
    if email is not None and email.strip() and email.strip().lower() != user.email.lower():
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden")


@router.post("/get_plant_info", response_model=PlantListResponse)
def get_plant_info(
    payload: PlantGetInfoRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> PlantListResponse:
    _enforce_email(user, str(payload.email) if payload.email else None)
    plants = db.scalars(select(Plant).where(Plant.user_id == user.id).order_by(Plant.created_at.desc())).all()
    results = [
        PlantPublic(
            uuid=p.uuid,
            plant_variety=p.plant_variety,
            plant_name=p.plant_name,
            plant_state=p.plant_state,
            setup_time=_fmt_ymd(p.setup_time),
            initialization=_fmt_ymd(p.initialization) if p.initialization else None,
            task=p.task,
        )
        for p in plants
    ]
    return PlantListResponse(results=results)

@router.post("/list", response_model=PlantSummaryListResponse)
def list_plants(
    payload: PlantGetInfoRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> PlantSummaryListResponse:
    _enforce_email(user, str(payload.email) if payload.email else None)
    plants = db.scalars(select(Plant).where(Plant.user_id == user.id).order_by(Plant.created_at.desc())).all()
    results = [
        PlantSummary(
            uuid=p.uuid,
            plant_variety=p.plant_variety,
            plant_name=p.plant_name,
            plant_state=p.plant_state,
            setup_time=_fmt_ymd(p.setup_time),
            initialization=_fmt_ymd(p.initialization) if p.initialization else None,
        )
        for p in plants
    ]
    return PlantSummaryListResponse(results=results)


@router.post("/create_plant", response_model=ApiMessage)
def create_plant(
    payload: PlantCreateRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ApiMessage:
    _enforce_email(user, str(payload.email) if payload.email else None)
    try:
        setup_time = parse_ymd(payload.setup_time)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Invalid setup_time")

    plant = Plant(
        uuid=str(uuidlib.uuid4()),
        user_id=user.id,
        plant_variety=payload.plant_variety,
        plant_name=payload.plant_name,
        plant_state=payload.plant_state,
        setup_time=setup_time,
    )
    db.add(plant)
    db.commit()
    return ApiMessage(message="Plant created")


@router.post("/update_plant", response_model=PlantDetail)
def update_plant(
    payload: PlantUpdateRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> PlantDetail:
    _enforce_email(user, str(payload.email) if payload.email else None)
    plant = db.scalar(select(Plant).where(Plant.uuid == payload.uuid, Plant.user_id == user.id))
    if plant is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Plant not found")

    try:
        setup_time = parse_ymd(payload.setup_time)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Invalid setup_time")

    plant.plant_variety = payload.plant_variety
    plant.plant_name = payload.plant_name
    plant.plant_state = payload.plant_state
    plant.setup_time = setup_time

    db.commit()
    db.refresh(plant)
    return PlantDetail(
        uuid=plant.uuid,
        plant_variety=plant.plant_variety,
        plant_name=plant.plant_name,
        plant_state=plant.plant_state,
        setup_time=_fmt_ymd(plant.setup_time),
        initialization=_fmt_ymd(plant.initialization) if plant.initialization else None,
        today_state=plant.today_state,
        last_watering_time=_fmt_ymdhms(plant.last_watering_time) if plant.last_watering_time else None,
        task=plant.task,
    )


@router.post("/delete_plant", response_model=ApiMessage)
def delete_plant(
    payload: PlantDeleteRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ApiMessage:
    _enforce_email(user, str(payload.email) if payload.email else None)
    plant = db.scalar(select(Plant).where(Plant.uuid == payload.uuid, Plant.user_id == user.id))
    if plant is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Plant not found")

    db.delete(plant)
    db.commit()
    return ApiMessage(message="Plant deleted")


@router.get("/{plant_uuid}", response_model=PlantDetail)
def get_plant_detail(
    plant_uuid: str,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> PlantDetail:
    plant = db.scalar(select(Plant).where(Plant.uuid == plant_uuid, Plant.user_id == user.id))
    if plant is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Plant not found")
    return PlantDetail(
        uuid=plant.uuid,
        plant_variety=plant.plant_variety,
        plant_name=plant.plant_name,
        plant_state=plant.plant_state,
        setup_time=_fmt_ymd(plant.setup_time),
        initialization=_fmt_ymd(plant.initialization) if plant.initialization else None,
        today_state=plant.today_state,
        last_watering_time=_fmt_ymdhms(plant.last_watering_time) if plant.last_watering_time else None,
        task=plant.task,
    )


@router.post("/initialize_plant", response_model=PlantDetail)
async def initialize_plant(
    payload: PlantInitializeRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> PlantDetail:
    _enforce_email(user, str(payload.email) if payload.email else None)
    plant = db.scalar(select(Plant).where(Plant.uuid == payload.uuid, Plant.user_id == user.id))
    if plant is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Plant not found")

    if payload.today_state is None or not payload.today_state.strip():
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Invalid today_state")

    plant.initialization = date.today()
    plant.today_state = payload.today_state
    if payload.last_watering_time:
        try:
            plant.last_watering_time = parse_ymdhms(payload.last_watering_time)
        except ValueError:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Invalid last_watering_time")

    plant.task = await _generate_tasks_for_plant(plant)
    db.commit()
    db.refresh(plant)
    return PlantDetail(
        uuid=plant.uuid,
        plant_variety=plant.plant_variety,
        plant_name=plant.plant_name,
        plant_state=plant.plant_state,
        setup_time=_fmt_ymd(plant.setup_time),
        initialization=_fmt_ymd(plant.initialization) if plant.initialization else None,
        today_state=plant.today_state,
        last_watering_time=_fmt_ymdhms(plant.last_watering_time) if plant.last_watering_time else None,
        task=plant.task,
    )


@router.post("/{plant_uuid}/generate_tasks", response_model=PlantDetail)
async def generate_tasks_for_plant(
    plant_uuid: str,
    payload: PlantGetInfoRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> PlantDetail:
    _enforce_email(user, str(payload.email) if payload.email else None)
    plant = db.scalar(select(Plant).where(Plant.uuid == plant_uuid, Plant.user_id == user.id))
    if plant is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Plant not found")

    if plant.initialization is None or plant.initialization != date.today():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Plant not initialized today")

    plant.task = await _generate_tasks_for_plant(plant)
    db.commit()
    db.refresh(plant)
    return PlantDetail(
        uuid=plant.uuid,
        plant_variety=plant.plant_variety,
        plant_name=plant.plant_name,
        plant_state=plant.plant_state,
        setup_time=_fmt_ymd(plant.setup_time),
        initialization=_fmt_ymd(plant.initialization) if plant.initialization else None,
        today_state=plant.today_state,
        last_watering_time=_fmt_ymdhms(plant.last_watering_time) if plant.last_watering_time else None,
        task=plant.task,
    )


@router.post("/update_plant_task", response_model=ApiMessage)
def update_plant_task(
    payload: PlantUpdateTaskRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ApiMessage:
    _enforce_email(user, str(payload.email) if payload.email else None)
    plant = db.scalar(select(Plant).where(Plant.uuid == payload.uuid, Plant.user_id == user.id))
    if plant is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Plant not found")

    decoded_task = _decode_task(payload.task)
    if decoded_task is None:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Invalid task")

    old_task = plant.task if isinstance(plant.task, dict) else {}
    new_points = 0
    for k, v in decoded_task.items():
        if not isinstance(v, dict):
            continue
        if not _is_true(v.get("state")):
            continue
        prev = old_task.get(k)
        prev_done = _is_true(prev.get("state")) if isinstance(prev, dict) else False
        if not prev_done:
            new_points += 1

    plant.task = decoded_task
    if new_points > 0:
        user.points = int(user.points or 0) + new_points
    db.commit()
    return ApiMessage(message="Task updated")
