import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class ForeChronoApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
    }

    function onStop(state) {
    }

    function getInitialView() {
        return [new ForeChronoView()];
    }

    // Called when the user changes settings in Garmin Connect / Connect IQ app
    function onSettingsChanged() {
        WatchUi.requestUpdate();
    }
}
