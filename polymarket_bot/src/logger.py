import sys
from pathlib import Path
from loguru import logger


def setup_logger(log_level: str = "INFO") -> None:
    logger.remove()

    logger.add(
        sys.stderr,
        level=log_level,
        format="<green>{time:YYYY-MM-DD HH:mm:ss}</green> | <level>{level: <8}</level> | <cyan>{name}</cyan>:<cyan>{line}</cyan> - <level>{message}</level>",
        colorize=True,
    )

    log_dir = Path("logs")
    log_dir.mkdir(exist_ok=True)

    logger.add(
        log_dir / "polymarket_bot_{time:YYYY-MM-DD}.log",
        level=log_level,
        format="{time:YYYY-MM-DD HH:mm:ss} | {level: <8} | {name}:{line} - {message}",
        rotation="00:00",
        retention="30 days",
        compression="gz",
    )


def get_logger(name: str):
    return logger.bind(name=name)
