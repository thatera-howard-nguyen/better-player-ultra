// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
package com.jhomlala.better_player

import io.flutter.plugin.common.EventChannel.EventSink
import java.util.ArrayList

/**
 * And implementation of [EventSink] which can wrap an underlying sink.
 * It delivers messages immediately when downstream is available, but it queues messages before
 * the delegate event sink is set with setDelegate.
 * Thread-safe: all operations are synchronized.
 */
internal class QueuingEventSink : EventSink {
    private var delegate: EventSink? = null
    private val eventQueue = ArrayList<Any>()
    private var done = false
    private val lock = Any()

    fun setDelegate(delegate: EventSink?) {
        synchronized(lock) {
            this.delegate = delegate
            maybeFlush()
        }
    }

    override fun endOfStream() {
        synchronized(lock) {
            enqueue(EndOfStreamEvent())
            maybeFlush()
            done = true
        }
    }

    override fun error(code: String, message: String, details: Any) {
        synchronized(lock) {
            enqueue(ErrorEvent(code, message, details))
            maybeFlush()
        }
    }

    override fun success(event: Any) {
        synchronized(lock) {
            enqueue(event)
            maybeFlush()
        }
    }

    private fun enqueue(event: Any) {
        if (done) {
            return
        }
        eventQueue.add(event)
    }

    private fun maybeFlush() {
        if (delegate == null) {
            return
        }
        for (event in eventQueue) {
            when (event) {
                is EndOfStreamEvent -> {
                    delegate!!.endOfStream()
                }
                is ErrorEvent -> {
                    delegate!!.error(event.code, event.message, event.details)
                }
                else -> {
                    delegate!!.success(event)
                }
            }
        }
        eventQueue.clear()
    }

    private class EndOfStreamEvent
    private class ErrorEvent(
        var code: String,
        var message: String,
        var details: Any
    )
}