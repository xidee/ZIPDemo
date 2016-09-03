//
//  H5ResourceModel.h
//  yintaiwang
//
//  Created by 细 Dee. on 16/7/25.
//  Copyright © 2016年 细 Dee. All rights reserved.
//  H5资源模型

#import <Foundation/Foundation.h>

@interface H5ResourceModel : NSObject

/**
 * applicationVersion
 */
@property (nonatomic ,copy) NSString *applicationVersion;
/**
 * zip 包下载地址
 */
@property (nonatomic ,copy) NSString *downloadUrl;
/**
 * zip 包大小
 */
@property (nonatomic ,assign) long size;
/**
 * zip 包 hash 值, 目前为 md5
 */
@property (nonatomic ,copy) NSString *md5;
/**
 * 资源类型, 目前为 "application/zip", 常见静态资源 mimeType 类型:
 * ["image/gif","image/jped","image/png","text/css","text/html","application/x-javascript","video/mpeg","video/3gpp","audio/x-aiff"]等
 */
@property (nonatomic ,copy) NSString *mimeType;
/**
 *  用来标识是否蜂窝下载
 */
@property (nonatomic ,assign) BOOL isMeterDownLoad;

@end
