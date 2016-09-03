//
//  H5UpgradeInfoModel.h
//  yintaiwang
//
//  Created by 细 Dee. on 16/7/25.
//  Copyright © 2016年 细 Dee. All rights reserved.
//  H5资源更新模型

#import <Foundation/Foundation.h>

@interface H5UpgradeInfoModel : NSObject
/**
 * 应用的最新版本, semantic version
 */
@property (nonatomic ,copy) NSString *latestVersion;
/**
 * 应用名称
 */
@property (nonatomic ,copy) NSString *application;
/**
 * 应用根目录,app 端 per 应用的删除缓存的依据
 */
@property (nonatomic ,copy) NSString *applicationRootDir;
/**
 * 顺序的下载资源描述
 */
@property (nonatomic ,strong) NSArray *resources;
/**
 * 是否全量
 */
@property (nonatomic ,assign) BOOL isWhole;
/**
 * 是否强制更新
 * 针对网络类型是wifi还是3G
 */
@property (nonatomic ,assign) BOOL isForceUpgrade;

@end
