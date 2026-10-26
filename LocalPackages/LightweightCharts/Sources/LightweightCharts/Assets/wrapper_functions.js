function promptFunction(objectName) {
    return function(params) {
        try {
            var payload = {object: objectName, params: params};
            var result = prompt(JSON.stringify(payload));
            return result;
        } catch(err) {
            console.error('Error with function ' + objectName + ':', err && err.message ? err.message : err);
            return null;
        }
    }
}

function promptJsonFunction(objectName) {
    return function(params) {
        try {
            var payload = {object: objectName, params: params};
            var result = prompt(JSON.stringify(payload));
            return result == null ? null : JSON.parse(result);
        } catch(err) {
            console.error('Error with function ' + objectName + ':', err && err.message ? err.message : err);
            return null;
        }
    }
}

function promptTickMarkFormatterFunction(objectName) {
    return function(time, tickMarkType, locale) {
        try {
            var payload = {object: objectName, params: {time: time, tickMarkType: tickMarkType, locale: locale}};
            var result = prompt(JSON.stringify(payload));
            return result;
        } catch(err) {
            console.error('Error with function ' + objectName + ':', err && err.message ? err.message : err);
            return null;
        }
    }
}

function promptAutoscaleInfoProviderFunction(objectName) {
    return function(baseImplementation) {
        try {
            var payload = {object: objectName, params: baseImplementation()};
            var result = prompt(JSON.stringify(payload));
            return result == null ? null : JSON.parse(result);
        } catch(err) {
            console.error('Error with function ' + objectName + ':', err && err.message ? err.message : err);
            return null;
        }
    }
}

function postMessageFunction(name) {
    return function(param) {
        var messageHandler = window.webkit?.messageHandlers?.[name];
        if (!messageHandler) {
            console.warn('Missing message handler: ' + name);
            return;
        }
        messageHandler.postMessage(JSON.stringify(param));
    }
}

function selectProps(...props) {
    return function (obj) {
        const newObj = {};
        props.forEach(name => {
            const value = obj[name];
            if (value !== undefined) {
                newObj[name] = value;
            }
        });
        
        return newObj;
    }
}

function subscriberCrosshairMoveAndClickFunction(name) {
    return function(param) {
        var dict = {};
        var hoveredSeriesName;

        seriesArray.forEach(function(stored) {
            var price = param.seriesData.get(stored.series);
            if (price != null) {
                dict[stored.name] = price;
            }

            if (param.hoveredSeries === stored.series) {
                hoveredSeriesName = stored.name;
            }
        });

        var parameters = {
            time: param.time,
            logical: param.logical,
            point: param.point,
            paneIndex: param.paneIndex,
            hoveredObjectId: param.hoveredObjectId,
            hoveredSeries: hoveredSeriesName,
            seriesData: dict
        };

        if (param.sourceEvent != undefined){
            parameters.sourceEvent = selectProps("clientX", "clientY", "pageX", "pageY", "screenX", "screenY",
                                                 "localX", "localY", "ctrlKey", "altKey", "shiftKey", "metaKey"
                                                 )(param.sourceEvent)
        }

        var messageHandler = window.webkit?.messageHandlers?.[name];
        if (!messageHandler) {
            console.warn('Missing message handler: ' + name);
            return;
        }
        messageHandler.postMessage(JSON.stringify(parameters));
    }
}

function formatDayMarksAsTime(chart) {
    var timeScale = chart.timeScale();
    var timeLabelFormatters = {};
    var lastHourMarksFit = null;

    function timeLabel(timeSeconds, locale) {
        var key = locale || '';
        if (!timeLabelFormatters[key]) {
            timeLabelFormatters[key] = new Intl.DateTimeFormat(locale || undefined, {
                hour: '2-digit',
                minute: '2-digit',
                hourCycle: 'h23',
                timeZone: 'UTC'
            });
        }
        return timeLabelFormatters[key].format(new Date(timeSeconds * 1000));
    }

    function hourMarksFit() {
        var range = timeScale.getVisibleRange();
        if (!range || typeof range.from !== 'number' || typeof range.to !== 'number') {
            return false;
        }
        var bars = timeScale.timeToIndex(range.to, false) - timeScale.timeToIndex(range.from, false);
        if (!(bars > 0) || !(range.to > range.from)) {
            return false;
        }
        var barSeconds = (range.to - range.from) / bars;
        var options = timeScale.options();
        var maxLabelWidth = (chart.options().layout.fontSize + 4) * 5 / 8 * (options.tickMarkMaxCharacterLength || 8);
        var maxIndexesPerMark = Math.ceil(maxLabelWidth / options.barSpacing);
        return 86400 / barSeconds / 2 >= maxIndexesPerMark;
    }

    function refreshLabels() {
        var fit = hourMarksFit();
        if (fit !== lastHourMarksFit) {
            lastHourMarksFit = fit;
            timeScale.applyOptions({});
        }
    }

    timeScale.applyOptions({
        tickMarkFormatter: function (time, tickMarkType, locale) {
            if (tickMarkType > 2 || typeof time !== 'number' || !hourMarksFit()) {
                return null;
            }
            return timeLabel(time, locale);
        }
    });
    timeScale.subscribeVisibleLogicalRangeChange(refreshLabels);
    timeScale.subscribeSizeChange(refreshLabels);
}
