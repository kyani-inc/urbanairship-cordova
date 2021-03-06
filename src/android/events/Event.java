/* Copyright Urban Airship and Contributors */

package com.urbanairship.cordova.events;

import android.support.annotation.NonNull;
import android.support.annotation.Nullable;

import org.json.JSONObject;

/**
 * Interface for Urban Airship Cordova events.
 */
public interface Event {

    /**
     * The event name.
     *
     * @return The event name.
     */
    @NonNull
    String getEventName();

    /**
     * The event data.
     *
     * @return The event data.
     */
    @Nullable
    JSONObject getEventData();
}
