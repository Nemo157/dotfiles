# vim:fileencoding=utf-8:et:sw=2:ts=2

from __future__ import absolute_import

import os
import sys
import re

from datetime import datetime
import socket
from multiprocessing import cpu_count as _cpu_count

from powerline.lib import add_divider_highlight_group
from powerline.lib.url import urllib_read, urllib_urlencode
from powerline.lib.vcs import guess, tree_status
from powerline.lib.threaded import ThreadedSegment, KwThreadedSegment, with_docstring
from powerline.lib.monotonic import monotonic
from powerline.lib.humanize_bytes import humanize_bytes
from powerline.theme import requires_segment_info
from collections import namedtuple


def _run_cmd(cmd):
  from subprocess import Popen, PIPE
  try:
    p = Popen(cmd, stdout=PIPE)
    stdout, err = p.communicate()
  except OSError as e:
    sys.stderr.write('Could not execute command ({0}): {1}\n'.format(e, cmd))
    return None
  return stdout.strip()

_airport_cmd = '/System/Library/PrivateFrameworks/Apple80211.framework/Versions/A/Resources/airport'

_state_regex = re.compile(' state: (.*)')
_ssid_regex = re.compile(' SSID: (.*)')
_bssid_regex = re.compile(' BSSID: (.*)')

def _get_airport_info():
  raw = _run_cmd([_airport_cmd, '-I'])
  state = _state_regex.search(raw)
  if state is None:
    if raw == 'AirPort: Off':
      state = 'off'
  else:
    state = state.group(1)
  ssid = _ssid_regex.search(raw)
  if ssid is None:
    ssid = ''
  else:
    ssid = ssid.group(1)
  return {
    "state":  state,
    "ssid": ssid
  }

@requires_segment_info
def state(pl, segment_info, running_text=None, off_text=None):
  airport_info = _get_airport_info()
  result = airport_info['state']
  if running_text is not None and result == 'running':
    result = running_text
  if off_text is not None and result == 'off':
    result = off_text
  return result

@requires_segment_info
def ssid(pl, segment_info, running_text=None, off_text=None):
  return _get_airport_info()['ssid']

@requires_segment_info
def format(pl, segment_info, format, running_text=None, off_text=None, init_text=None):
  airport_info = _get_airport_info()
  if airport_info['state'] == 'running':
    airport_info['state'] = running_text
  if airport_info['state'] == 'off':
    airport_info['state'] = off_text
  if airport_info['state'] == 'init':
    airport_info['state'] = init_text
  return format % airport_info
