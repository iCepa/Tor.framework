//
//  TORLogging.m
//  Tor
//
//  Created by Benjamin Erhart on 9/9/17.
//

#import "TORLogging.h"

#import <event2/event.h>
#import <asl.h>
#import "torlog.h"

tor_log_cb tor_log_callback;
tor_log_cb event_log_callback;

NS_ASSUME_NONNULL_BEGIN

static char *subsystem = "org.torproject.Tor";

static inline const char *TORLegacyLevelFromOSLogType(os_log_type_t type) {
    switch (type) {
        case OS_LOG_TYPE_ERROR:
            return "3";
        case OS_LOG_TYPE_INFO:
            return "4";
        case OS_LOG_TYPE_DEBUG:
        default:
            return "5";
    }
}

static void TORLegacyLog(os_log_type_t type, const char *msg) {
    static dispatch_once_t onceToken;
    static aslclient log = NULL;
    dispatch_once(&onceToken, ^{
        log = asl_open(NULL, "com.apple.console", 0);
    });

    char read_uid[16];
    snprintf(read_uid, sizeof(read_uid), "%d", geteuid());

    aslmsg message = asl_new(ASL_TYPE_MSG);
    if (message != NULL) {
        if (asl_set(message, ASL_KEY_LEVEL, TORLegacyLevelFromOSLogType(type)) == 0 &&
            asl_set(message, ASL_KEY_MSG, msg) == 0 &&
            asl_set(message, ASL_KEY_READ_UID, read_uid) == 0) {
            asl_send(log, message);
        }
        asl_free(message);
    }
}

static inline os_log_type_t TORLogTypeFromEventSeverity(int severity) {
    switch (severity) {
        case EVENT_LOG_ERR:
        case EVENT_LOG_WARN:
            return OS_LOG_TYPE_ERROR;
        case EVENT_LOG_MSG:
            return OS_LOG_TYPE_INFO;
        case EVENT_LOG_DEBUG:
            return OS_LOG_TYPE_DEBUG;
        default:
            return OS_LOG_TYPE_DEFAULT;
    }
}

static void TOREventLogCallback(int severity, const char *msg) {
    os_log_type_t type = TORLogTypeFromEventSeverity(severity);

    if (event_log_callback) {
        event_log_callback(type, msg);
    } else if (@available(iOS 10.0, macOS 10.12, *)) {
        static dispatch_once_t onceToken;
        static os_log_t log = NULL;
        dispatch_once(&onceToken, ^{
            log = os_log_create(subsystem, "libevent");
        });

        os_log_with_type(log, type, "%{public}s", msg);
    } else {
        TORLegacyLog(type, msg);
    }
}

static const char * __nullable TORCategoryForDomain(uint32_t domain) {
    switch (domain) {
        case LD_GENERAL:
            return "general";
        case LD_CRYPTO:
            return "crypto";
        case LD_NET:
            return "net";
        case LD_CONFIG:
            return "config";
        case LD_FS:
            return "fs";
        case LD_PROTOCOL:
            return "protocol";
        case LD_MM:
            return "mm";
        case LD_HTTP:
            return "http";
        case LD_APP:
            return "app";
        case LD_CONTROL:
            return "control";
        case LD_CIRC:
            return "circ";
        case LD_REND:
            return "rend";
        case LD_BUG:
            return "bug";
        case LD_DIR:
            return "dir";
        case LD_DIRSERV:
            return "dirserv";
        case LD_OR:
            return "or";
        case LD_EDGE:
            return "edge";
        case LD_ACCT:
            return "acct";
        case LD_HIST:
            return "hist";
        case LD_HANDSHAKE:
            return "handshake";
        case LD_HEARTBEAT:
            return "heartbeat";
        case LD_CHANNEL:
            return "channel";
        case LD_SCHED:
            return "sched";
        case LD_GUARD:
            return "guard";
        default:
            return NULL;
    }
}

static inline os_log_type_t TORLogTypeFromSeverity(int severity) {
    switch (severity) {
        case LOG_ERR:
            return OS_LOG_TYPE_FAULT;
        case LOG_WARN:
            return OS_LOG_TYPE_ERROR;
        case LOG_NOTICE:
        case LOG_INFO:
            return OS_LOG_TYPE_INFO;
        case LOG_DEBUG:
            return OS_LOG_TYPE_DEBUG;
        default:
            return OS_LOG_TYPE_DEFAULT;
    }
}

static void TORLogCallback(int severity, uint32_t domain, const char *msg) {
    if (domain & LD_NOCB) {
        return;
    }

    os_log_type_t type = TORLogTypeFromSeverity(severity);

    if (tor_log_callback) {
        tor_log_callback(type, msg);
    } else if (@available(iOS 10.0, macOS 10.12, *)) {
        int index = 0;
        while (domain >>= 1) {
            ++index;
        }
        if (index >= N_LOGGING_DOMAINS) {
            return;
        }

        static os_log_t logs[N_LOGGING_DOMAINS] = { NULL };
        os_log_t log = logs[index];
        if (log == NULL) {
            log = os_log_create(subsystem, TORCategoryForDomain(1u << index));
            logs[index] = log;
        }

        os_log_with_type(log, type, "%{public}s", msg);
    } else {
        TORLegacyLog(type, msg);
    }
}

void TORInstallEventLogging(void) {
    event_log_callback = NULL;
    event_set_log_callback(TOREventLogCallback);
    event_enable_debug_logging(EVENT_DBG_ALL);
}

void TORInstallEventLoggingCallback(tor_log_cb cb) {
    event_log_callback = cb;
    event_set_log_callback(TOREventLogCallback);
    event_enable_debug_logging(EVENT_DBG_ALL);
}

void TORInstallTorLogging(void) {
    tor_log_callback = NULL;
    log_severity_list_t list;
    set_log_severity_config(LOG_DEBUG, LOG_ERR, &list);
    add_callback_log(&list, TORLogCallback);
}

extern void TORInstallTorLoggingCallback(tor_log_cb cb) {
    tor_log_callback = cb;
    log_severity_list_t list;
    set_log_severity_config(LOG_DEBUG, LOG_ERR, &list);
    add_callback_log(&list, TORLogCallback);
}

NS_ASSUME_NONNULL_END

