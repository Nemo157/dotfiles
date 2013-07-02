# vim:fileencoding=utf-8:noet

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


_current_source_regex = re.compile('Currently drawing from \'(.*)\'')
_current_percent_regex = re.compile('(\\d+)%')
_charging_regex = re.compile('charging')
_discharging_regex = re.compile('discharging')
_not_charging_regex = re.compile('not charging')
_time_remaining_regex = re.compile('((\d+):(\d+)) remaining')

def _get_battery_info():
  raw = _run_cmd(['/usr/bin/pmset', '-g', 'batt'])
  current_source = _current_source_regex.search(raw)
  if current_source is not None:
    current_source = current_source.group(1)
  current_percent = _current_percent_regex.search(raw)
  if current_percent is not None:
    current_percent = int(current_percent.group(1))
  charging = not not (_charging_regex.search(raw) and not _discharging_regex.search(raw) and not _not_charging_regex.search(raw))
  discharging = not not _discharging_regex.search(raw)
  time_remaining = _time_remaining_regex.search(raw)
  if time_remaining is not None:
    hours_remaining = int(time_remaining.group(2))
    minutes_remaining = int(time_remaining.group(2))
    time_remaining = time_remaining.group(1)
  if time_remaining is None or time_remaining == '0:00':
    hours_remaining = 0
    minutes_remaining = 0
    time_remaining = ''
  return {
    "current_source":  current_source,
    "current_percent": current_percent,
    "charging":        charging,
    "discharging":     discharging,
    "time_remaining":  time_remaining,
    "hours_remaining":  hours_remaining,
    "minutes_remaining":  minutes_remaining
  }

def _calculate_fuzzy_time_remaining(hours, minutes):
  if hours < 1:
    if minutes < 2:
      return str(minutes) + ' minute'
    else:
      return str(minutes) + ' minutes'
  elif hours < 2:
    if minutes < 30:
      return str(minutes + 60) + ' minutes'
    else:
      return str((hours + 1)) + ' hours'
  else:
    if minutes < 30:
      return str(hours) + ' hours'
    else:
      return str((hours + 1)) + ' hours'


@requires_segment_info
def current_source(pl, segment_info, AC_text=None, battery_text=None):
  battery_info = _get_battery_info()
  result = battery_info['current_source']
  if AC_text is not None and result == 'AC Power':
    result = AC_text
  if battery_text is not None and result == 'Battery Power':
    result = battery_text
  return result

@requires_segment_info
def current_percent(pl, segment_info):
  battery_info = _get_battery_info()
  return battery_info['current_percent'] + '%'

@requires_segment_info
def charging(pl, segment_info, charging_text='charging', discharging_text='discharging', not_charging_text=None):
  battery_info = _get_battery_info()
  return charging_text if battery_info['charging'] else (discharging_text if battery_info['discharging'] else not_charging_text)

@requires_segment_info
def time_remaining(pl, segment_info):
  battery_info = _get_battery_info()
  return battery_info['time_remaining']

@requires_segment_info
def format(pl, segment_info, format, time_format=None, AC_text=None, battery_text=None, charging_text='charging', discharging_text='discharging', not_charging_text=''):
  battery_info = _get_battery_info()
  battery_info['charging_state'] = charging_text if battery_info['charging'] else (discharging_text if battery_info['discharging'] else not_charging_text)
  if AC_text is not None and battery_info['current_source'] == 'AC Power':
    battery_info['current_source'] = AC_text
  if battery_text is not None and battery_info['current_source'] == 'Battery Power':
    battery_info['current_source'] = battery_text
  if time_format is not None:
    battery_info['fuzzy_time_remaining'] = _calculate_fuzzy_time_remaining(battery_info['hours_remaining'], battery_info['minutes_remaining'])
    battery_info['formatted_time_remaining'] = time_format % battery_info
  if battery_info['time_remaining'] == '':
    battery_info['formatted_time_remaining'] = ''
  return format % battery_info
