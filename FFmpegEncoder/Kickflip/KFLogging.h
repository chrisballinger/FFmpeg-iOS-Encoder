//
//  KFLogging.h
//  FFmpegEncoder
//
//  Created by Christopher Ballinger on 1/22/14.
//  Copyright (c) 2014 Christopher Ballinger. All rights reserved.
//

#ifndef _KFLogging_h
#define _KFLogging_h

#ifndef LOG_LEVEL_DEF
#define LOG_LEVEL_DEF ddKickflipLogLevel
#endif

#import "DDLog.h"

#ifdef DEBUG
static const int ddKickflipLogLevel = LOG_LEVEL_VERBOSE;
#else
static const int ddKickflipLogLevel = LOG_LEVEL_OFF;
#endif

#endif
