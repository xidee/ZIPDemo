//
//  YTURLProtocol.h
//  WebviewCache
//
//  Created by xidee on 16/3/31.
//  Copyright © 2016年 xidee All rights reserved.
//

#import <Foundation/Foundation.h>

@interface YTURLProtocol : NSURLProtocol <NSURLSessionDelegate>

@property (nonatomic ,strong) NSURLSession *session;

@end
