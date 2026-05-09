(function() {
    'use strict';

    // Override Notification API to bridge to native macOS notifications
    const OriginalNotification = window.Notification;

    function MessengerNotification(title, options) {
        options = options || {};

        // Forward to native handler
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.notifications) {
            window.webkit.messageHandlers.notifications.postMessage({
                title: String(title || ''),
                body: String(options.body || ''),
                tag: String(options.tag || ''),
                icon: String(options.icon || '')
            });
        }

        // Return a stub so web code doesn't break
        return {
            close: function() {},
            addEventListener: function() {},
            removeEventListener: function() {}
        };
    }

    // Copy static properties
    MessengerNotification.permission = 'granted';
    MessengerNotification.requestPermission = function() {
        return Promise.resolve('granted');
    };

    window.Notification = MessengerNotification;

    // Watch title for unread badge count: "(3) Messenger"
    function updateBadge() {
        const title = document.title || '';
        const match = title.match(/^\((\d+)\)/);
        const count = match ? parseInt(match[1], 10) : 0;
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.badgeCount) {
            window.webkit.messageHandlers.badgeCount.postMessage(count);
        }
    }

    // Watch <title> changes
    const titleEl = document.querySelector('title');
    if (titleEl) {
        new MutationObserver(updateBadge).observe(titleEl, { childList: true, subtree: true });
    }

    // Also watch for dynamic title element creation
    new MutationObserver(function() {
        const t = document.querySelector('title');
        if (t) {
            new MutationObserver(updateBadge).observe(t, { childList: true, subtree: true });
        }
        updateBadge();
    }).observe(document.documentElement, { childList: true, subtree: true });

})();
