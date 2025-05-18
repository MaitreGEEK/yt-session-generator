import asyncio
import dataclasses
import json
import logging
import time
from dataclasses import dataclass
from pathlib import Path
from tempfile import mkdtemp
from typing import Optional

import nodriver

logger = logging.getLogger('extractor')


@dataclass
class TokenInfo:
    updated: int
    potoken: str
    visitor_data: str

    def to_json(self) -> str:
        as_dict = dataclasses.asdict(self)
        as_json = json.dumps(as_dict)
        return as_json


class PotokenExtractor:

    def __init__(self, loop: asyncio.AbstractEventLoop,
                 update_interval: float = 3600,
                 browser_path: Optional[Path] = None) -> None:
        self.update_interval: float = update_interval
        self.browser_path: Optional[Path] = browser_path
        self.profile_path = mkdtemp()
        self._loop = loop
        self._token_info: Optional[TokenInfo] = None
        self._ongoing_update: asyncio.Lock = asyncio.Lock()
        self._extraction_done: asyncio.Event = asyncio.Event()
        self._update_requested: asyncio.Event = asyncio.Event()
        # It's good practice to also control headless mode via a parameter if needed
        # For server environments, headless should usually be True.
        # The original call had headless=False, which assumes Xvfb is perfectly redirecting.
        # nodriver might handle its own headlessness better if headless=True is passed when Xvfb isn't the primary goal.
        # However, the error message specifically points to no_sandbox.
        self.headless_mode = False # Or True if preferred for server, but original was False

    def get(self) -> Optional[TokenInfo]:
        return self._token_info

    async def run_once(self) -> Optional[TokenInfo]:
        await self._update()
        return self.get()

    async def run(self) -> None:
        await self._update()
        while True:
            try:
                await asyncio.wait_for(self._update_requested.wait(), timeout=self.update_interval)
                logger.debug('initiating force update')
            except asyncio.TimeoutError:
                logger.debug('initiating scheduled update')
            await self._update()
            self._update_requested.clear()

    def request_update(self) -> bool:
        if self._ongoing_update.locked():
            logger.debug('update process is already running')
            return False
        if self._update_requested.is_set():
            logger.debug('force update has already been requested')
            return False
        self._loop.call_soon_threadsafe(self._update_requested.set)
        logger.debug('force update requested')
        return True

    @staticmethod
    def _extract_token(request: nodriver.cdp.network.Request) -> Optional[TokenInfo]:
        post_data = request.post_data
        try:
            post_data_json = json.loads(post_data)
            visitor_data = post_data_json['context']['client']['visitorData']
            potoken = post_data_json['serviceIntegrityDimensions']['poToken']
        except (json.JSONDecodeError, TypeError, KeyError) as e:
            logger.warning(f'failed to extract token from request: {type(e)}, {e}')
            return None
        token_info = TokenInfo(
            updated=int(time.time()),
            potoken=potoken,
            visitor_data=visitor_data
        )
        return token_info

    async def _update(self) -> None:
        try:
            await asyncio.wait_for(self._perform_update(), timeout=600)
        except asyncio.TimeoutError:
            logger.error('update failed: hard limit timeout exceeded. Browser might be failing to start properly')

    async def _perform_update(self) -> None:
        if self._ongoing_update.locked():
            logger.debug('update is already in progress')
            return

        async with self._ongoing_update:
            logger.info('update started')
            self._extraction_done.clear()
            try:
                # --- MODIFICATION IS HERE ---
                browser = await nodriver.start(
                    headless=self.headless_mode, # Using the class attribute
                    browser_executable_path=self.browser_path,
                    user_data_dir=self.profile_path,
                    no_sandbox=True  # Added this based on the error message
                )
                # --- END OF MODIFICATION ---
            except FileNotFoundError as e:
                msg = "could not find Chromium. Make sure it's installed or provide direct path to the executable"
                raise FileNotFoundError(msg) from e
            except Exception as e: # Catch other potential startup errors from nodriver
                logger.error(f"Nodriver failed to start browser: {e}")
                # Potentially re-raise or handle to prevent silent exit
                raise # Re-raise the exception so it's visible and the process might exit if it's fatal

            tab = browser.main_tab
            tab.add_handler(nodriver.cdp.network.RequestWillBeSent, self._send_handler)
            await tab.get('https://www.youtube.com/watch?v=oitx514tQgk&pp=0gcJCdgAo7VqN5tD5') # Changed number for uniqueness
            player_clicked = await self._click_on_player(tab)
            if player_clicked:
                await self._wait_for_handler()
            await tab.close() # Ensure tab is closed
            # browser.stop() # nodriver's __aexit__ in Browser class should handle cleanup.
            # If explicit stop is needed:
            try:
                if browser and browser.connection: # Check if connection exists before trying to stop/close
                    await browser.close() # prefer close over stop usually
                elif browser:
                    browser.stop() # Fallback if no connection object to aclose
            except Exception as e:
                logger.warning(f"Exception during browser stop/close: {e}")


    @staticmethod
    async def _click_on_player(tab: nodriver.Tab) -> bool:
        try:
            player = await tab.select('#movie_player', 10)
        except asyncio.TimeoutError:
            logger.warning('update failed: unable to locate video player on the page')
            return False
        else:
            await player.click()
            return True

    async def _wait_for_handler(self) -> bool:
        try:
            await asyncio.wait_for(self._extraction_done.wait(), timeout=30)
        except asyncio.TimeoutError:
            logger.warning('update failed: timeout waiting for outgoing API request')
            return False
        else:
            logger.info('update was succeessful')
            return True

    async def _send_handler(self, event: nodriver.cdp.network.RequestWillBeSent) -> None:
        if not event.request.method == 'POST':
            return
        if '/youtubei/v1/player' not in event.request.url:
            return
        token_info = self._extract_token(event.request)
        if token_info is None:
            return
        logger.info(f'new token: {token_info.to_json()}')
        self._token_info = token_info
        self._extraction_done.set()