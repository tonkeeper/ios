var meta = document.createElement('meta');
meta.setAttribute('name', 'viewport');
meta.setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0, user-scalable=no, shrink-to-fit=no');
document.getElementsByTagName('head')[0].appendChild(meta);
document.body.style.margin = 0;
// The chart lives on document.body. Reserve vertical panning for the native
// scroll layer so a vertical drag scrolls the host page instead of being
// captured by the chart; horizontal pan and pinch still reach the chart's JS.
document.body.style.touchAction = 'pan-y';
