(function() {
    window.TKLightweightCharts = window.TKLightweightCharts || {};

    function evenlySpaced(start, end, count) {
        if (count < 2) {
            return [start];
        }
        const step = (end - start) / (count - 1);
        return Array.from({ length: count }, (_, index) => start + step * index);
    }

    const defaultOptions = {
        markers: [],
        priceDecimals: 2,
        priceGroupingSeparator: " ",
        lineWidth: 1,
        lineOpacity: 0.32,
        fontSize: 12,
        fontFamily: "SFMono-Semibold, SF Mono, SFMono-Regular, ui-monospace, monospace",
        fontWeight: "600",
        tagRadius: 4,
        tagPaddingX: 4,
        tagPaddingTop: 1,
        tagPaddingBottom: 2,
        tagMinHeight: 16,
        tagMinWidth: 0,
        axisFontSize: 12,
        axisWordSpacing: -5,
        axisFontFamily: "SFMono-Medium, SF Mono, SFMono-Regular, ui-monospace, monospace",
        axisFontWeight: "500",
        axisTagFontFamily: "SFMono-Semibold, SF Mono, SFMono-Regular, ui-monospace, monospace",
        axisTagFontWeight: "600",
        axisTagRadius: 4,
        axisTagPaddingX: 4,
        axisTagPaddingTop: 1,
        axisTagPaddingBottom: 2,
        axisTagMinHeight: 16,
        axisTagMinWidth: 0,
        axisTagTextRightInset: 16,
        currentPriceUpLabelColor: "#39CC83",
        currentPriceUpLabelBackgroundColor: "#16332F",
        currentPriceDownLabelColor: "#FF4766",
        currentPriceDownLabelBackgroundColor: "#361D2A",
        axisLabelsVisible: true,
        axisLabelColor: "#8994A3",
        axisLabelTextRightInset: 16,
        // When set, the crosshair dot snaps onto the series value at the hovered
        // time instead of tracking the finger's y.
        crosshairDotOnSeries: false,
        leadingX: 16,
        trailingX: 0,
        dotHaloSize: 24,
        dotSize: 8,
        dotHaloColor: "rgba(255, 255, 255, 0.08)",
        dotColor: "rgba(255, 255, 255, 1)",
        crosshairVisible: true,
        crosshairColor: "#FFFFFF",
        crosshairLineWidth: 1,
        crosshairDash: [3, 3],
        gridVisible: true,
        gridColor: "rgba(194, 218, 255, 0.08)",
        gridLineWidth: 0.5,
        // Grid geometry is pane-relative: the *Y / *Height values are fractions
        // [0,1] of the pane height, while the vertical-line start/step are absolute
        // pixels so the spacing stays constant across device widths.
        gridHorizontalStartX: 0,
        gridHorizontalWidth: null,
        gridHorizontalY: evenlySpaced(0.125, 0.792, 4),
        gridVerticalStartX: 34,
        gridVerticalStep: 60,
        gridVerticalY: 0.127,
        gridVerticalHeight: 0.89,
        gridFadeColor: null,
        markerLineStartX: 0,
        markerLineWidth: null,
        markerLineDash: [],
        crosshairVerticalY: 0,
        crosshairVerticalHeight: null,
        crosshairHorizontalStartX: 0,
        crosshairHorizontalWidth: null,
        crosshairLabelColor: "#FFFFFF",
        crosshairLabelBackgroundColor: "#363B43",
        pinnedTagGap: 2,
        pinnedTagsBottomY: 1,
        pinnedArrowSize: 8,
        pinnedArrowGap: 4,
        pinnedArrowLineWidth: 1.5,
    };

    function roundRect(ctx, x, y, width, height, radius) {
        const r = Math.min(radius, width / 2, height / 2);
        ctx.beginPath();
        ctx.moveTo(x + r, y);
        ctx.lineTo(x + width - r, y);
        ctx.quadraticCurveTo(x + width, y, x + width, y + r);
        ctx.lineTo(x + width, y + height - r);
        ctx.quadraticCurveTo(x + width, y + height, x + width - r, y + height);
        ctx.lineTo(x + r, y + height);
        ctx.quadraticCurveTo(x, y + height, x, y + height - r);
        ctx.lineTo(x, y + r);
        ctx.quadraticCurveTo(x, y, x + r, y);
        ctx.closePath();
    }

    function fillRoundRect(ctx, x, y, width, height, radius) {
        if (ctx.roundRect) {
            const r = Math.min(radius, width / 2, height / 2);
            ctx.beginPath();
            ctx.roundRect(x, y, width, height, r);
        } else {
            roundRect(ctx, x, y, width, height, radius);
        }
        ctx.fill();
    }

    function alignPixel(value) {
        return Math.round(value) + 0.5;
    }

    function lineExtent(start, width, extent) {
        const begin = start || 0;
        return { start: begin, end: width == null ? extent : begin + width };
    }

    function transparentColor(color) {
        const match = String(color).match(/^rgba?\s*\((\d+),\s*(\d+),\s*(\d+)(?:,\s*([.\d]+))?\)$/);
        if (!match) {
            return "rgba(194, 218, 255, 0)";
        }
        return `rgba(${match[1]}, ${match[2]}, ${match[3]}, 0)`;
    }

    function cachedTextWidth(ctx, cache, font, text) {
        const key = `${font}\n${text}`;
        const cached = cache.get(key);
        if (cached !== undefined) {
            return cached;
        }

        const width = ctx.measureText(text).width;
        cache.set(key, width);
        return width;
    }

    function formatPrice(value, options) {
        if (typeof value !== "number" || !Number.isFinite(value)) {
            return "";
        }

        return formatAxisPrice(value, Math.max(2, options.priceDecimals || 0), options.priceGroupingSeparator || " ");
    }

    function formatAxisPrice(value, decimals, groupingSeparator) {
        const fixed = value.toFixed(decimals);
        const trimmed = fixed.includes(".")
            ? fixed.replace(/(\.\d{2}.*?)0+$/, "$1")
            : fixed;
        const parts = trimmed.split(".");
        const sign = parts[0].startsWith("-") ? "-" : "";
        const integer = sign ? parts[0].slice(1) : parts[0];
        const grouped = integer.replace(/\B(?=(\d{3})+(?!\d))/g, groupingSeparator);
        return `${sign}${grouped}${parts[1] ? `.${parts[1]}` : ""}`;
    }

    function tagHeight(options) {
        const measuredTagHeight = Math.ceil(options.fontSize + options.tagPaddingTop + options.tagPaddingBottom);
        return Math.max(measuredTagHeight, options.tagMinHeight || 0);
    }

    function tagMetrics(ctx, cache, font, text, options) {
        const textWidth = cachedTextWidth(ctx, cache, font, text);
        const measuredTagWidth = Math.ceil(textWidth + options.tagPaddingX * 2);
        const tagWidth = Math.max(measuredTagWidth, options.tagMinWidth || 0);
        return { tagWidth, tagHeight: tagHeight(options) };
    }

    function pinTagsToEdges(items, paneHeight, options) {
        const height = tagHeight(options);
        const step = height + options.pinnedTagGap;
        const plotBottom = options.pinnedTagsBottomY * paneHeight;
        const minY = options.pinnedTagGap + height / 2;
        const maxY = plotBottom - options.pinnedTagGap - height / 2;
        const tags = items.filter(item => item.align !== "right" && item.title);
        const above = tags.filter(item => item.y < 0).sort((a, b) => a.y - b.y);
        const below = tags.filter(item => item.y > plotBottom).sort((a, b) => b.y - a.y);
        above.forEach((item, index) => {
            item.edge = "top";
            item.tagY = minY + index * step;
        });
        below.forEach((item, index) => {
            item.edge = "bottom";
            item.tagY = maxY - index * step;
        });

        const inRange = tags.filter(item => item.edge == null).sort((a, b) => a.y - b.y);
        for (const item of inRange) {
            item.tagY = Math.min(Math.max(item.y, minY), maxY);
        }
        let floor = minY + above.length * step;
        for (const item of inRange) {
            if (item.tagY >= floor) {
                break;
            }
            item.tagY = floor;
            floor += step;
        }
        let ceiling = maxY - below.length * step;
        for (const item of [...inRange].reverse()) {
            if (item.tagY <= ceiling) {
                break;
            }
            item.tagY = ceiling;
            ceiling -= step;
        }
    }

    function drawEdgeArrow(context, x, centerY, edge, color, options) {
        const size = options.pinnedArrowSize;
        const head = size / 2;
        const direction = edge === "top" ? -1 : 1;
        const tipY = centerY + direction * size / 2;
        const tailY = centerY - direction * size / 2;

        context.save();
        context.strokeStyle = color;
        context.lineWidth = options.pinnedArrowLineWidth;
        context.lineCap = "round";
        context.lineJoin = "round";
        context.setLineDash([]);
        context.beginPath();
        context.moveTo(x, tailY);
        context.lineTo(x, tipY);
        context.moveTo(x - head, tipY - direction * head);
        context.lineTo(x, tipY);
        context.lineTo(x + head, tipY - direction * head);
        context.stroke();
        context.restore();
    }

    function drawPinnedTag(context, x, centerY, item, backgroundColor, options, textWidthCache, font) {
        const textWidth = cachedTextWidth(context, textWidthCache, font, item.title);
        const arrowWidth = options.pinnedArrowGap + options.pinnedArrowSize;
        const width = Math.max(Math.ceil(textWidth + options.tagPaddingX * 2 + arrowWidth), options.tagMinWidth || 0);
        const height = tagHeight(options);
        const top = Math.round(centerY - height / 2);
        const textX = x + options.tagPaddingX;

        context.fillStyle = backgroundColor;
        fillRoundRect(context, x, top, width, height, options.tagRadius);
        context.fillStyle = item.color;
        context.textAlign = "left";
        context.fillText(item.title, textX, top + height / 2);
        drawEdgeArrow(context, textX + textWidth + arrowWidth - options.pinnedArrowSize / 2, top + height / 2, item.edge, item.color, options);
    }

    function drawTag(context, x, centerY, title, color, backgroundColor, options, textWidthCache, font, textAlign) {
        const { tagWidth, tagHeight } = tagMetrics(context, textWidthCache, font, title, options);
        const tagY = Math.round(centerY - tagHeight / 2);

        context.fillStyle = backgroundColor;
        fillRoundRect(context, x, tagY, tagWidth, tagHeight, options.tagRadius);

        context.fillStyle = color;
        context.textAlign = textAlign || "left";
        const textX = textAlign === "right"
            ? x + tagWidth - options.tagPaddingX
            : x + options.tagPaddingX;
        context.fillText(title, textX, tagY + tagHeight / 2);
        return { width: tagWidth, height: tagHeight };
    }

    function axisStyle(options) {
        return {
            ...options,
            fontSize: options.axisFontSize,
            fontFamily: options.axisTagFontFamily || options.axisFontFamily,
            fontWeight: options.axisTagFontWeight || options.axisFontWeight,
            tagRadius: options.axisTagRadius,
            tagPaddingX: options.axisTagPaddingX,
            tagPaddingTop: options.axisTagPaddingTop,
            tagPaddingBottom: options.axisTagPaddingBottom,
            tagMinHeight: options.axisTagMinHeight,
            tagMinWidth: options.axisTagMinWidth,
        };
    }

    function axisTagX(mediaWidth, tagWidth, style) {
        return Math.max(0, axisTextX(mediaWidth, style) - tagWidth + style.tagPaddingX);
    }

    function axisTextX(mediaWidth, style) {
        const inset = style.axisLabelTextRightInset ?? style.axisTagTextRightInset ?? style.tagPaddingX;
        return Math.max(0, mediaWidth - inset);
    }

    function axisValueLabels(series, mediaHeight, options) {
        if (!series || !options.axisLabelsVisible) {
            return [];
        }

        return options.gridHorizontalY
            .map(fraction => {
                const y = fraction * mediaHeight;
                return { y, title: formatPrice(series.coordinateToPrice(y), options) };
            })
            .filter(label => label.title);
    }

    function markerTitle(marker, options) {
        const price = formatPrice(marker.price, options);
        if (marker.align === "right") {
            return price;
        }
        // Left lines (TP/Entry/SL/Liq) read "NAME price" in one bubble; the name
        // is uppercased to match the app's tag styling.
        return marker.title ? `${marker.title.toUpperCase()} ${price}` : price;
    }

    function colorRgb(color) {
        if (typeof color !== "string") {
            return null;
        }
        const value = color.trim();
        const hex = value.match(/^#?([0-9a-f]{6})$/i);
        if (hex) {
            const number = parseInt(hex[1], 16);
            return [(number >> 16) & 255, (number >> 8) & 255, number & 255];
        }
        const rgb = value.match(/rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)/i);
        if (rgb) {
            return [Number(rgb[1]), Number(rgb[2]), Number(rgb[3])];
        }
        return null;
    }

    function colorWithAlpha(color, alpha) {
        const rgb = colorRgb(color);
        if (rgb == null) {
            return color;
        }
        return `rgba(${Math.round(rgb[0])}, ${Math.round(rgb[1])}, ${Math.round(rgb[2])}, ${alpha})`;
    }

    function axisItemTagColors(item, options) {
        if (!item.isCurrentPrice) {
            return {
                color: item.color,
                backgroundColor: item.backgroundColor || colorWithAlpha(item.color, 0.16),
            };
        }
        const isDown = item.direction === "down";
        return {
            color: isDown ? options.currentPriceDownLabelColor : options.currentPriceUpLabelColor,
            backgroundColor: isDown ? options.currentPriceDownLabelBackgroundColor : options.currentPriceUpLabelBackgroundColor,
        };
    }

    function verticalGridX(startX, step, mediaWidth) {
        if (step == null || step <= 0) {
            return [];
        }
        const result = [];
        for (let x = startX || 0; x <= mediaWidth + 0.5; x += step) {
            result.push(x);
        }
        return result;
    }

    class GridRenderer {
        constructor(data) {
            this._data = data;
        }

        draw(target) {
            target.useMediaCoordinateSpace(({ context, mediaSize }) => {
                const { options } = this._data;
                if (!options.gridVisible) {
                    return;
                }

                const { width, height } = mediaSize;
                const horizontalLine = lineExtent(options.gridHorizontalStartX, options.gridHorizontalWidth, width);
                const verticalY = options.gridVerticalY * height;
                const verticalHeight = options.gridVerticalHeight * height;
                const gridFadeColor = options.gridFadeColor || transparentColor(options.gridColor);

                context.save();
                context.lineWidth = options.gridLineWidth;
                context.strokeStyle = options.gridColor;

                for (const fraction of options.gridHorizontalY) {
                    const alignedY = alignPixel(fraction * height);
                    context.beginPath();
                    context.moveTo(horizontalLine.start, alignedY);
                    context.lineTo(horizontalLine.end, alignedY);
                    context.stroke();
                }

                for (const x of verticalGridX(options.gridVerticalStartX, options.gridVerticalStep, width)) {
                    const alignedX = alignPixel(x);
                    const gradient = context.createLinearGradient(0, verticalY, 0, verticalY + verticalHeight);
                    gradient.addColorStop(0, options.gridColor);
                    gradient.addColorStop(1, gridFadeColor);
                    context.strokeStyle = gradient;
                    context.beginPath();
                    context.moveTo(alignedX, verticalY);
                    context.lineTo(alignedX, verticalY + verticalHeight);
                    context.stroke();
                }

                context.restore();
            });
        }
    }

    class OverlayRenderer {
        constructor(data) {
            this._data = data;
        }

        draw(target) {
            target.useMediaCoordinateSpace(({ context, mediaSize }) => {
                const { options, items, dot, textWidthCache } = this._data;
                const font = `${options.fontWeight} ${options.fontSize}px ${options.fontFamily}`;
                const markerLine = lineExtent(options.markerLineStartX, options.markerLineWidth, mediaSize.width);
                const crosshairVertical = lineExtent(options.crosshairVerticalY, options.crosshairVerticalHeight, mediaSize.height);
                const crosshairHorizontal = lineExtent(options.crosshairHorizontalStartX, options.crosshairHorizontalWidth, mediaSize.width);

                context.save();
                context.font = font;
                context.textBaseline = "middle";

                for (const item of items) {
                    const y = alignPixel(item.y);
                    if (item.lineVisible !== false && item.edge == null) {
                        context.save();
                        context.globalAlpha = options.lineOpacity;
                        context.strokeStyle = item.lineColor || item.color;
                        context.lineWidth = options.lineWidth;
                        context.lineCap = "round";
                        context.setLineDash(options.markerLineDash);
                        context.beginPath();
                        context.moveTo(markerLine.start, y);
                        context.lineTo(markerLine.end, y);
                        context.stroke();
                        context.restore();
                    }

                    if (!item.title) {
                        continue;
                    }

                    if (item.align === "right") {
                        continue;
                    }

                    const backgroundColor = item.backgroundColor || colorWithAlpha(item.color, 0.16);
                    if (item.edge == null) {
                        drawTag(context, options.leadingX, alignPixel(item.tagY ?? item.y), item.title, item.color, backgroundColor, options, textWidthCache, font);
                    } else {
                        drawPinnedTag(context, options.leadingX, alignPixel(item.tagY), item, backgroundColor, options, textWidthCache, font);
                    }
                }

                if (dot && options.crosshairVisible) {
                    context.save();
                    context.strokeStyle = options.crosshairColor;
                    context.lineWidth = options.crosshairLineWidth;
                    context.lineCap = "round";
                    context.setLineDash(options.crosshairDash);
                    context.beginPath();
                    context.moveTo(alignPixel(dot.x), crosshairVertical.start);
                    context.lineTo(alignPixel(dot.x), crosshairVertical.end);
                    context.stroke();
                    context.beginPath();
                    context.moveTo(crosshairHorizontal.start, alignPixel(dot.y));
                    context.lineTo(crosshairHorizontal.end, alignPixel(dot.y));
                    context.stroke();
                    context.restore();
                }

                if (dot) {
                    context.fillStyle = options.dotHaloColor;
                    context.beginPath();
                    context.arc(dot.x, dot.y, options.dotHaloSize / 2, 0, Math.PI * 2);
                    context.fill();

                    context.fillStyle = options.dotColor;
                    context.beginPath();
                    context.arc(dot.x, dot.y, options.dotSize / 2, 0, Math.PI * 2);
                    context.fill();
                }

                context.restore();
            });
        }
    }

    class AxisRenderer {
        constructor(data) {
            this._data = data;
        }

        draw(target) {
            target.useMediaCoordinateSpace(({ context, mediaSize }) => {
                const { options, axisItems, dot, textWidthCache, series } = this._data;
                const style = axisStyle(options);
                const labelFont = `${options.axisFontWeight} ${options.axisFontSize}px ${options.axisFontFamily}`;
                const tagFont = `${style.fontWeight} ${style.fontSize}px ${style.fontFamily}`;

                context.save();
                context.wordSpacing = `${options.axisWordSpacing}px`;
                context.font = tagFont;
                context.textBaseline = "middle";

                const tagYs = axisItems.filter(item => item.title).map(item => item.y);
                if (dot && dot.title) {
                    tagYs.push(dot.y);
                }
                const labelClearance = (style.tagMinHeight + options.axisFontSize) / 2;
                context.font = labelFont;
                context.fillStyle = options.axisLabelColor;
                context.textAlign = "right";
                for (const label of axisValueLabels(series, mediaSize.height, options)) {
                    if (tagYs.some(y => Math.abs(y - label.y) < labelClearance)) {
                        continue;
                    }
                    context.fillText(label.title, axisTextX(mediaSize.width, style), alignPixel(label.y));
                }

                context.font = tagFont;
                for (const item of axisItems) {
                    if (!item.title) {
                        continue;
                    }
                    const { tagWidth } = tagMetrics(context, textWidthCache, tagFont, item.title, style);
                    const x = axisTagX(mediaSize.width, tagWidth, style);
                    const colors = axisItemTagColors(item, options);
                    drawTag(context, x, alignPixel(item.y), item.title, colors.color, colors.backgroundColor, style, textWidthCache, tagFont, "right");
                }

                if (dot && dot.title) {
                    const { tagWidth } = tagMetrics(context, textWidthCache, tagFont, dot.title, style);
                    const x = axisTagX(mediaSize.width, tagWidth, style);
                    drawTag(
                        context,
                        x,
                        alignPixel(dot.y),
                        dot.title,
                        options.crosshairLabelColor,
                        options.crosshairLabelBackgroundColor,
                        style,
                        textWidthCache,
                        tagFont,
                        "right"
                    );
                }

                context.restore();
            });
        }
    }

    class PrimitivePaneView {
        constructor(source, zOrder, rendererFactory) {
            this._source = source;
            this._zOrder = zOrder;
            this._rendererFactory = rendererFactory;
        }

        zOrder() {
            return this._zOrder;
        }

        renderer() {
            return this._rendererFactory(this._source.data());
        }
    }

    class PriceMarkersPrimitive {
        constructor(options) {
            this._options = { ...defaultOptions, ...options };
            this._items = [];
            this._axisItems = [];
            this._textWidthCache = new Map();
            this._paneViews = [
                new PrimitivePaneView(this, "bottom", data => new GridRenderer(data)),
                new PrimitivePaneView(this, "top", data => new OverlayRenderer(data)),
            ];
            this._priceAxisPaneViews = [
                new PrimitivePaneView(this, "top", data => new AxisRenderer(data)),
            ];
            this._series = null;
            this._chart = null;
            this._crosshairHandler = null;
            this._dot = null;
            this._updateFrame = null;
            this._requestUpdate = null;
        }

        attached({ chart, series, requestUpdate }) {
            this._chart = chart;
            this._series = series;
            this._requestUpdate = requestUpdate;
            this._crosshairHandler = (param) => {
                if (!param || !param.point || !param.time) {
                    this._dot = null;
                    this._scheduleUpdate();
                    return;
                }

                const x = chart.timeScale().timeToCoordinate(param.time);
                let y = param.point.y;
                let price = series.coordinateToPrice(param.point.y);
                if (this._options.crosshairDotOnSeries) {
                    const data = param.seriesData && param.seriesData.get(series);
                    const value = data == null ? null : (data.value != null ? data.value : data.close);
                    const coord = value == null ? null : series.priceToCoordinate(value);
                    if (coord != null) {
                        y = coord;
                        price = value;
                    }
                }
                const title = formatPrice(price, this._options);
                this._dot = x == null ? null : { x, y, title };
                this._scheduleUpdate();
            };
            chart.subscribeCrosshairMove(this._crosshairHandler);
            this._requestUpdate();
        }

        detached() {
            if (this._updateFrame !== null) {
                cancelAnimationFrame(this._updateFrame);
            }
            if (this._chart && this._crosshairHandler) {
                this._chart.unsubscribeCrosshairMove(this._crosshairHandler);
            }
            this._chart = null;
            this._series = null;
            this._crosshairHandler = null;
            this._dot = null;
            this._updateFrame = null;
            this._requestUpdate = null;
        }

        updateAllViews() {
            const markers = this._options.markers || [];
            if (!this._series || !markers.length) {
                this._items = [];
                this._axisItems = [];
                return;
            }

            this._items = markers
                .map((marker) => {
                    const y = this._series.priceToCoordinate(marker.price);
                    return y == null ? null : { ...marker, y, title: markerTitle(marker, this._options) };
                })
                .filter(Boolean);
            pinTagsToEdges(this._items, this._chart.paneSize().height, this._options);
            this._axisItems = this._items.filter((item) => item.align === "right");
        }

        paneViews() {
            return this._paneViews;
        }

        priceAxisPaneViews() {
            return this._priceAxisPaneViews;
        }

        data() {
            return {
                options: this._options,
                items: this._items,
                axisItems: this._axisItems,
                dot: this._dot,
                series: this._series,
                textWidthCache: this._textWidthCache,
            };
        }

        applyOptions(options) {
            this._options = { ...this._options, ...options };
            this._textWidthCache.clear();
            this._requestUpdate && this._requestUpdate();
        }

        setMarkers(markers) {
            this._options = { ...this._options, markers };
            this._requestUpdate && this._requestUpdate();
        }

        _scheduleUpdate() {
            if (!this._requestUpdate || this._updateFrame !== null) {
                return;
            }

            this._updateFrame = requestAnimationFrame(() => {
                this._updateFrame = null;
                this._requestUpdate && this._requestUpdate();
            });
        }
    }

    window.TKLightweightCharts.createPriceLevelMarkers = function(series, options) {
        const primitive = new PriceMarkersPrimitive(options || {});
        series.attachPrimitive(primitive);
        return {
            detach: function() {
                series.detachPrimitive(primitive);
            },
            applyOptions: function(options) {
                primitive.applyOptions(options || {});
            },
            setMarkers: function(markers) {
                primitive.setMarkers(markers || []);
            },
        };
    };
})();
