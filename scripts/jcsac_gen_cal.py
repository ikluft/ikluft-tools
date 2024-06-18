#!/usr/bin/env python3
"""
generate calendar entries for collaboration of Space Crew for JetCityStar's Aerospace Chat
by Ian Kluft
"""

import sys
import os
import re
import tempfile
from zoneinfo import ZoneInfo
from datetime import datetime, date, timedelta
from icalendar import Calendar, Event, Alarm

# constants
DATE_RE = r"^([0-9]{4})-([0-9]{2})-([0-9]{2})$"
TIME_RE = r"^([0-9]{2}):([0-9]{2}):([0-9]{2})$"
DEFAULT_TIME = "17:00:00"
DEFAULT_TZ = "America/Los_Angeles"
STORY_DL_HOUR = 9
RANKING_DL_HOUR = 9


def usage():
    """print program usage"""
    print("usage: " + sys.argv[0] + " YYYY-MM-DD [HH:MM:SS] [timezone]", file=sys.stderr)


def gen_alarm(alert_time: timedelta, description: str) -> Alarm:
    """generate an Alarm subcomponent to be added into event components"""
    alarm = Alarm()
    alarm.add("action", "DISPLAY")
    alarm.add('trigger', alert_time)
    alarm.add('description', description)
    return alarm


def dl1_event(d_t: dict) -> Event:
    """generate event for space story submission deadline"""
    event = Event()
    event.add('summary',
              'space story submission deadline for Aerospace Chat ' + d_t["jcsac_date"])
    event.add('description',
              "Space Crew story submissions due - this deadline gives a day for the team to rank "
              + "the space stories before Isaac needs the list to prepare for the Aerospace Chat")
    event.add('dtstart', d_t["story_dl_dt"])
    event.add('dtend', d_t["story_dl_dt"])
    event.add('created', d_t["now"])
    event.add_component(gen_alarm(alert_time=timedelta(hours=-24),
                                  description="submit space stories for Aerospace Chat"))
    event.add('sequence', 0)
    return event


def dl2_event(d_t: dict) -> Event:
    """generate event for space story ranking deadine"""
    event = Event()
    event.add('summary', 'space story ranking deadline for Aerospace Chat ' + d_t["jcsac_date"])
    event.add('description',
              "Space Crew story rankings due - this deadline gives some hours on Friday before "
              + "the Sunday chat for Ian to process the individual rankings into a group ranking "
              + "and send the results to Isaac")
    event.add('dtstart', d_t["ranking_dl_dt"])
    event.add('dtend', d_t["ranking_dl_dt"])
    event.add('created', d_t["now"])
    event.add_component(gen_alarm(alert_time=timedelta(hours=-6),
                                  description="submit space story ranking for Aerospace Chat"))
    event.add('sequence', 1)
    return event


def jcs_event(d_t: dict) -> Event:
    """generate main event for JetCityStar Aerospace Chat"""
    event = Event()
    event.add('summary', 'JetCityStar Aerospace Chat ' + d_t["jcsac_date"])
    event.add('description',
              "Aerospace chat hosted by Isaac @JetCityStar and Nick @JetTipNet "
              + "- Zoom meeting details distributed via email")
    event.add('dtstart', d_t["chat_start"])
    event.add('dtend', d_t["chat_end"])
    event.add('created', d_t["now"])
    event.add_component(gen_alarm(alert_time=timedelta(hours=-1),
                                  description="@JetCityStar Aerospace Chat"))
    event.add('sequence', 2)
    return event


def run() -> int:
    """main function"""
    d_t = {}

    # read date and optional time & zone from command line
    if len(sys.argv) <= 1:
        usage()
        return 1
    d_t["jcsac_date"] = sys.argv[1]  # date of JCS Aerospace Chat
    date_result = re.match(DATE_RE, d_t["jcsac_date"])
    if date_result is None:
        raise RuntimeError("date must be formatted as YYYY-MM-DD")
    d_t["jcsac_time"] = sys.argv[2] if len(sys.argv) >= 3 else DEFAULT_TIME
    time_result = re.match(TIME_RE, d_t["jcsac_time"])
    if time_result is None:
        raise RuntimeError("time must be formatted as HH:MM::SS, if provided")
    jcsac_zone = sys.argv[3] if len(sys.argv) >= 4 else DEFAULT_TZ
    d_t["jcsac_tz"] = ZoneInfo(jcsac_zone)

    # compute dates
    d_t["now"] = datetime.now(tz=d_t["jcsac_tz"])
    d_t["chat_start"] = datetime(int(date_result[1]), int(date_result[2]), int(date_result[3]),
                                 int(time_result[1]), int(time_result[2]), int(time_result[3]),
                                 tzinfo=d_t["jcsac_tz"])
    print("JCS Aerospace Chat time: ", d_t["chat_start"])
    d_t["chat_date"] = date(d_t["chat_start"].year, d_t["chat_start"].month, d_t["chat_start"].day)
    d_t["chat_end"] = d_t["chat_start"] + timedelta(hours=2)
    story_dl_date = d_t["chat_date"] - timedelta(days=3)
    d_t["story_dl_dt"] = datetime(story_dl_date.year, story_dl_date.month, story_dl_date.day,
                                  STORY_DL_HOUR, 0, 0, tzinfo=d_t["jcsac_tz"])
    ranking_dl_date = d_t["chat_date"] - timedelta(days=2)
    d_t["ranking_dl_dt"] = datetime(ranking_dl_date.year, ranking_dl_date.month,
                                    ranking_dl_date.day,
                                    RANKING_DL_HOUR, 0, 0, tzinfo=d_t["jcsac_tz"])

    # generate Ical calendar
    cal = Calendar()

    # generate event for space story submission deadline
    cal.add_component(dl1_event(d_t))

    # generate event for space story ranking deadine
    cal.add_component(dl2_event(d_t))

    # generate main event for JetCityStar Aerospace Chat
    cal.add_component(jcs_event(d_t))

    # write output
    print(cal.to_ical().decode("utf-8"))
    directory = tempfile.mkdtemp(prefix="jcsac-space")
    outpath = os.path.join(directory, 'jcsac-space-' + d_t["jcsac_date"] + '.ics')
    with open(outpath, 'wb') as outfile:
        outfile.write(cal.to_ical())
    print("output to ", outpath)
    return 0


if __name__ == "__main__":
    sys.exit(run())
