import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;
import Toybox.Weather;

// Analog "chronograph" style watch face inspired by the Garmin fenix/epix
// premium dials: gold-and-lume sword hands, applied indices, three
// sub-dials (heart rate, steps, weather) and four corner data fields
// (battery, altitude, calories, distance).
class ForeChronoView extends WatchUi.WatchFace {

    const GOLD = 0xC9A66B;
    const GOLD_DARK = 0x7A6238;
    const LUME = 0xF4F1E6;
    const SILVER = 0xB8BCC2;
    const GREY = 0x6E747C;
    const SUBDIAL = 0x07090D;

    // Hand shapes as [distance along hand, sideways offset], in units of radius
    const HOUR_HAND = [[-0.06, -0.020], [0.17, -0.013], [0.20, -0.048], [0.43, -0.038],
                       [0.52, 0.0], [0.43, 0.038], [0.20, 0.048], [0.17, 0.013], [-0.06, 0.020]];
    const HOUR_LUME = [[0.225, -0.030], [0.42, -0.023], [0.485, 0.0], [0.42, 0.023], [0.225, 0.030]];
    const MIN_HAND = [[-0.08, -0.018], [0.30, -0.011], [0.33, -0.036], [0.72, -0.027],
                      [0.80, 0.0], [0.72, 0.027], [0.33, 0.036], [0.30, 0.011], [-0.08, 0.018]];
    const MIN_LUME = [[0.355, -0.021], [0.71, -0.016], [0.765, 0.0], [0.71, 0.016], [0.355, 0.021]];

    var _cx = 0.0;
    var _cy = 0.0;
    var _r = 0.0;
    var _sleeping = false;
    var _burnIn = false;

    var _fNum;
    var _fDay;
    var _fDate;
    var _fVal;
    var _fSmall;
    var _fTiny;

    function initialize() {
        WatchFace.initialize();
        var ds = System.getDeviceSettings();
        if (ds has :requiresBurnInProtection) {
            _burnIn = ds.requiresBurnInProtection;
        }
    }

    function onLayout(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        _cx = w / 2.0;
        _cy = h / 2.0;
        _r = (w < h ? w : h) / 2.0;

        // Pick fonts by pixel height so the layout scales on every screen size
        _fNum = pickFont(dc, [Graphics.FONT_NUMBER_MEDIUM, Graphics.FONT_NUMBER_MILD,
                              Graphics.FONT_LARGE, Graphics.FONT_MEDIUM], _r * 0.26);
        _fDay = pickFont(dc, [Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY], _r * 0.13);
        _fDate = pickFont(dc, [Graphics.FONT_MEDIUM, Graphics.FONT_SMALL, Graphics.FONT_TINY], _r * 0.16);
        _fVal = pickFont(dc, [Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY], _r * 0.13);
        _fSmall = pickFont(dc, [Graphics.FONT_TINY, Graphics.FONT_XTINY], _r * 0.115);
        _fTiny = Graphics.FONT_XTINY;
    }

    function pickFont(dc, fonts, maxHeight) {
        for (var i = 0; i < fonts.size(); i++) {
            if (dc.getFontHeight(fonts[i]) <= maxHeight) {
                return fonts[i];
            }
        }
        return fonts[fonts.size() - 1];
    }

    function onEnterSleep() {
        _sleeping = true;
        WatchUi.requestUpdate();
    }

    function onExitSleep() {
        _sleeping = false;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }
        var clock = System.getClockTime();

        // AMOLED always-on mode: minimal outline face to avoid burn-in
        if (_sleeping && _burnIn) {
            drawAlwaysOn(dc, clock);
            return;
        }

        var theme = getProp("Theme", 0);
        var showSeconds = getProp("ShowSeconds", true);

        drawDial(dc, theme);
        drawMinuteTrack(dc);
        drawIndices(dc);
        drawDate(dc);
        drawCornerData(dc);
        drawHeartRateDial(dc, _cx - _r * 0.43, _cy + _r * 0.04, _r * 0.21);
        drawStepsDial(dc, _cx + _r * 0.43, _cy + _r * 0.04, _r * 0.21);
        drawWeatherDial(dc, _cx, _cy + _r * 0.44, _r * 0.19);
        drawHands(dc, clock, showSeconds && !_sleeping);
    }

    function getProp(key, fallback) {
        var v = null;
        try {
            v = Application.Properties.getValue(key);
        } catch (e) {
            v = null;
        }
        return v == null ? fallback : v;
    }

    // ------------------------------------------------------------------ geometry

    function xAt(angleDeg, rad) {
        return _cx + rad * Math.sin(angleDeg * Math.PI / 180.0);
    }

    function yAt(angleDeg, rad) {
        return _cy - rad * Math.cos(angleDeg * Math.PI / 180.0);
    }

    // Converts a hand shape (in radius units) into screen points at a given angle
    function shapeToPoints(shape, angleDeg, dx, dy) {
        var a = angleDeg * Math.PI / 180.0;
        var s = Math.sin(a);
        var c = Math.cos(a);
        var pts = new [shape.size()];
        for (var i = 0; i < shape.size(); i++) {
            var along = shape[i][0] * _r;
            var side = shape[i][1] * _r;
            pts[i] = [_cx + dx + along * s + side * c, _cy + dy - along * c + side * s];
        }
        return pts;
    }

    function radialLine(dc, angleDeg, r1, r2) {
        dc.drawLine(xAt(angleDeg, r1), yAt(angleDeg, r1), xAt(angleDeg, r2), yAt(angleDeg, r2));
    }

    function drawOutline(dc, pts) {
        var n = pts.size();
        for (var i = 0; i < n; i++) {
            var p = pts[i];
            var q = pts[(i + 1) % n];
            dc.drawLine(p[0], p[1], q[0], q[1]);
        }
    }

    // ------------------------------------------------------------------ dial

    function drawDial(dc, theme) {
        var bg = 0x0B1F3F;
        var texture = 0x173463;
        var bezel = 0x04070D;
        if (theme == 1) {
            bg = 0x121212;
            texture = 0x262626;
            bezel = 0x050505;
        }

        dc.setColor(bezel, bezel);
        dc.clear();

        dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_cx, _cy, _r * 0.885);

        // Concentric "engine turned" rings
        dc.setPenWidth(1);
        dc.setColor(texture, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 13; i++) {
            dc.drawCircle(_cx, _cy, _r * (0.52 + i * 0.027));
        }

        // Sunburst guilloché in the centre
        for (var a = 0; a < 360; a += 6) {
            radialLine(dc, a, _r * 0.10, _r * 0.50);
        }

        dc.setColor(SUBDIAL, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_cx, _cy, _r * 0.09);

        // Chapter ring edge
        dc.setPenWidth(2);
        dc.setColor(GREY, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(_cx, _cy, _r * 0.885);
    }

    function drawMinuteTrack(dc) {
        for (var i = 0; i < 60; i++) {
            var a = i * 6;
            if (i % 10 == 0) {
                var label = (i == 0) ? "60" : i.toString();
                dc.setColor(GREY, Graphics.COLOR_TRANSPARENT);
                dc.drawText(xAt(a, _r * 0.94), yAt(a, _r * 0.94), _fTiny, label,
                            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            } else if (i % 5 == 0) {
                dc.setPenWidth(3);
                dc.setColor(SILVER, Graphics.COLOR_TRANSPARENT);
                radialLine(dc, a, _r * 0.91, _r * 0.98);
            } else {
                dc.setPenWidth(1);
                dc.setColor(GREY, Graphics.COLOR_TRANSPARENT);
                radialLine(dc, a, _r * 0.94, _r * 0.98);
            }
        }
    }

    function drawIndices(dc) {
        // Applied baton indices: gold frame with lume insert
        for (var h = 1; h < 12; h++) {
            if (h == 3 || h == 6 || h == 9) {
                continue;
            }
            var a = h * 30;
            dc.setColor(GOLD, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon(shapeToPoints([[0.70, -0.024], [0.84, -0.024], [0.84, 0.024], [0.70, 0.024]], a, 0, 0));
            dc.setColor(LUME, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon(shapeToPoints([[0.715, -0.010], [0.825, -0.010], [0.825, 0.010], [0.715, 0.010]], a, 0, 0));
        }

        // Large numerals at 12, 3, 6, 9 with a dark drop shadow
        var nums = ["12", "3", "6", "9"];
        for (var i = 0; i < 4; i++) {
            var a = i * 90;
            var x = xAt(a, _r * 0.765);
            var y = yAt(a, _r * 0.765);
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x + 2, y + 2, _fNum, nums[i], Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(GOLD, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, y, _fNum, nums[i], Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    function drawDate(dc) {
        var info = Gregorian.info(Time.now(), Time.FORMAT_LONG);
        var day = info.day_of_week.toString().toUpper();
        dc.setColor(LUME, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _cy - _r * 0.42, _fDay, day, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(_cx, _cy - _r * 0.285, _fDate, info.day.toString(),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ------------------------------------------------------------------ data

    function drawCornerData(dc) {
        var ds = System.getDeviceSettings();
        var statute = (ds.distanceUnits == System.UNIT_STATUTE);

        // Battery ("POWER")
        var battery = System.getSystemStats().battery.toNumber().toString() + "%";

        // Altitude
        var alt = "--";
        var ai = Activity.getActivityInfo();
        if (ai != null && ai.altitude != null) {
            var m = ai.altitude;
            if (ds.elevationUnits == System.UNIT_STATUTE) {
                m = m * 3.28084;
            }
            alt = m.toNumber().toString();
        }

        // Calories and distance
        var kcal = "--";
        var dist = "--";
        var am = ActivityMonitor.getInfo();
        if (am != null) {
            if (am.calories != null) {
                kcal = am.calories.toString();
            }
            if (am.distance != null) {
                var d = am.distance / (statute ? 160934.4 : 100000.0);
                dist = d.format("%.1f");
            }
        }

        drawDataField(dc, 315, battery, "POWER");
        drawDataField(dc, 45, alt, "ALT");
        drawDataField(dc, 225, kcal, "KCAL");
        drawDataField(dc, 135, dist, statute ? "MI" : "KM");
    }

    function drawDataField(dc, angle, value, label) {
        var x = xAt(angle, _r * 0.60);
        var y = yAt(angle, _r * 0.60);
        var gap = _r * 0.055;
        dc.setColor(LUME, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y - gap, _fVal, value, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(GOLD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y + gap, _fTiny, label, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function drawSubdialBase(dc, x, y, rad) {
        dc.setColor(SUBDIAL, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, rad);
        dc.setPenWidth(2);
        dc.setColor(GREY, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(x, y, rad);
        // Side ticks crossing the ring, like a chronograph register
        dc.setColor(SILVER, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x - rad * 1.08, y, x - rad * 0.80, y);
        dc.drawLine(x + rad * 0.80, y, x + rad * 1.08, y);
        dc.setPenWidth(1);
        dc.drawLine(x, y - rad, x, y - rad * 0.85);
        dc.drawLine(x, y + rad * 0.85, x, y + rad);
    }

    function drawHeartRateDial(dc, x, y, rad) {
        drawSubdialBase(dc, x, y, rad);

        var hr = null;
        var ai = Activity.getActivityInfo();
        if (ai != null && ai.currentHeartRate != null) {
            hr = ai.currentHeartRate;
        }
        if (hr == null && (ActivityMonitor has :getHeartRateHistory)) {
            var sample = ActivityMonitor.getHeartRateHistory(1, true).next();
            if (sample != null && sample.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
                hr = sample.heartRate;
            }
        }

        drawHeart(dc, x, y - rad * 0.40, _r * 0.032);
        dc.setColor(LUME, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y + rad * 0.32, _fVal, hr == null ? "--" : hr.toString(),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function drawStepsDial(dc, x, y, rad) {
        drawSubdialBase(dc, x, y, rad);

        var steps = "--";
        var am = ActivityMonitor.getInfo();
        if (am != null && am.steps != null) {
            steps = am.steps.toString();
        }

        drawSteps(dc, x, y - rad * 0.40, _r * 0.03);
        dc.setColor(LUME, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y + rad * 0.32, _fVal, steps, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function drawWeatherDial(dc, x, y, rad) {
        drawSubdialBase(dc, x, y, rad);

        var temp = "--";
        var range = "";
        var cond = -1;
        if (Toybox has :Weather) {
            var cc = Weather.getCurrentConditions();
            if (cc != null) {
                var statute = (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE);
                if (cc.temperature != null) {
                    temp = toUnit(cc.temperature, statute).toString() + "°" + (statute ? "F" : "C");
                }
                if (cc.highTemperature != null && cc.lowTemperature != null) {
                    range = toUnit(cc.highTemperature, statute).toString() + "/" +
                            toUnit(cc.lowTemperature, statute).toString();
                }
                if (cc.condition != null) {
                    cond = cc.condition;
                }
            }
        }

        drawWeatherIcon(dc, x, y - rad * 0.48, _r * 0.03, cond);
        dc.setColor(LUME, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y + rad * 0.05, _fSmall, temp, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(GOLD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y + rad * 0.55, _fTiny, range, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function toUnit(celsius, statute) {
        if (statute) {
            return (celsius * 9.0 / 5.0 + 32.0).toNumber();
        }
        return celsius.toNumber();
    }

    // ------------------------------------------------------------------ icons

    function drawHeart(dc, x, y, s) {
        dc.setColor(LUME, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x - s * 0.5, y - s * 0.2, s * 0.55);
        dc.fillCircle(x + s * 0.5, y - s * 0.2, s * 0.55);
        dc.fillPolygon([[x - s * 1.03, y], [x + s * 1.03, y], [x, y + s * 1.15]]);
    }

    function drawSteps(dc, x, y, s) {
        dc.setColor(LUME, Graphics.COLOR_TRANSPARENT);
        dc.fillEllipse(x - s * 0.6, y + s * 0.15, s * 0.38, s * 0.7);
        dc.fillCircle(x - s * 0.6, y + s * 1.15, s * 0.28);
        dc.fillEllipse(x + s * 0.6, y - s * 0.35, s * 0.38, s * 0.7);
        dc.fillCircle(x + s * 0.6, y + s * 0.65, s * 0.28);
    }

    function drawCloud(dc, x, y, s, color) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x - s * 0.55, y + s * 0.15, s * 0.5);
        dc.fillCircle(x + s * 0.1, y - s * 0.15, s * 0.7);
        dc.fillCircle(x + s * 0.75, y + s * 0.2, s * 0.45);
        dc.fillRectangle(x - s * 0.55, y + s * 0.15, s * 1.3, s * 0.5);
    }

    function drawSun(dc, x, y, s) {
        dc.setColor(0xF2C14E, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, s * 0.55);
        dc.setPenWidth(2);
        for (var a = 0; a < 360; a += 45) {
            var rad = a * Math.PI / 180.0;
            dc.drawLine(x + s * 0.8 * Math.sin(rad), y - s * 0.8 * Math.cos(rad),
                        x + s * 1.1 * Math.sin(rad), y - s * 1.1 * Math.cos(rad));
        }
    }

    function drawWeatherIcon(dc, x, y, s, cond) {
        if (cond == Weather.CONDITION_CLEAR || cond == Weather.CONDITION_MOSTLY_CLEAR ||
            cond == Weather.CONDITION_FAIR) {
            drawSun(dc, x, y, s);
        } else if (cond == Weather.CONDITION_PARTLY_CLOUDY || cond == Weather.CONDITION_PARTLY_CLEAR) {
            drawSun(dc, x - s * 0.5, y - s * 0.35, s * 0.85);
            drawCloud(dc, x + s * 0.2, y + s * 0.15, s * 0.9, LUME);
        } else if (cond == Weather.CONDITION_RAIN || cond == Weather.CONDITION_SHOWERS ||
                   cond == Weather.CONDITION_LIGHT_RAIN || cond == Weather.CONDITION_HEAVY_RAIN ||
                   cond == Weather.CONDITION_THUNDERSTORMS) {
            drawCloud(dc, x, y - s * 0.3, s * 0.9, LUME);
            dc.setColor(0x5AA9E6, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            for (var i = -1; i <= 1; i++) {
                dc.drawLine(x + i * s * 0.55, y + s * 0.6, x + i * s * 0.55 - s * 0.25, y + s * 1.1);
            }
        } else if (cond == Weather.CONDITION_SNOW || cond == Weather.CONDITION_LIGHT_SNOW ||
                   cond == Weather.CONDITION_HEAVY_SNOW) {
            drawCloud(dc, x, y - s * 0.3, s * 0.9, LUME);
            dc.setColor(LUME, Graphics.COLOR_TRANSPARENT);
            for (var i = -1; i <= 1; i++) {
                dc.fillCircle(x + i * s * 0.55, y + s * 0.85, s * 0.15);
            }
        } else if (cond >= 0) {
            drawCloud(dc, x, y, s, SILVER);
        }
    }

    // ------------------------------------------------------------------ hands

    function drawHands(dc, clock, showSeconds) {
        var hourAngle = ((clock.hour % 12) + clock.min / 60.0) * 30.0;
        var minAngle = (clock.min + (showSeconds ? clock.sec / 60.0 : 0.0)) * 6.0;

        drawSwordHand(dc, hourAngle, HOUR_HAND, HOUR_LUME);
        drawSwordHand(dc, minAngle, MIN_HAND, MIN_LUME);

        if (showSeconds) {
            var secAngle = clock.sec * 6.0;
            var pen = _r * 0.012;
            dc.setPenWidth(pen < 2 ? 2 : pen.toNumber());
            dc.setColor(GOLD, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(xAt(secAngle, -_r * 0.18), yAt(secAngle, -_r * 0.18),
                        xAt(secAngle, _r * 0.86), yAt(secAngle, _r * 0.86));
            dc.fillCircle(xAt(secAngle, -_r * 0.14), yAt(secAngle, -_r * 0.14), _r * 0.028);
        }

        // Centre pivot
        dc.setColor(GOLD, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_cx, _cy, _r * 0.038);
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_cx, _cy, _r * 0.016);
    }

    function drawSwordHand(dc, angle, frame, lume) {
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(shapeToPoints(frame, angle, 3, 3));
        dc.setColor(GOLD, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(shapeToPoints(frame, angle, 0, 0));
        dc.setColor(LUME, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(shapeToPoints(lume, angle, 0, 0));
    }

    // ------------------------------------------------------------------ always-on

    function drawAlwaysOn(dc, clock) {
        dc.setColor(0x000000, 0x000000);
        dc.clear();

        // Shift everything a few pixels each minute to protect the AMOLED panel
        var shift = ((clock.min % 5) - 2) * 2;

        dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 12; i++) {
            var a = i * 30;
            dc.fillCircle(xAt(a, _r * 0.80) + shift, yAt(a, _r * 0.80) + shift, (i % 3 == 0) ? 3 : 2);
        }

        var hourAngle = ((clock.hour % 12) + clock.min / 60.0) * 30.0;
        var minAngle = clock.min * 6.0;
        dc.setPenWidth(2);
        dc.setColor(GOLD_DARK, Graphics.COLOR_TRANSPARENT);
        drawOutline(dc, shapeToPoints(HOUR_HAND, hourAngle, shift, shift));
        drawOutline(dc, shapeToPoints(MIN_HAND, minAngle, shift, shift));
        dc.drawCircle(_cx + shift, _cy + shift, _r * 0.038);
    }
}
