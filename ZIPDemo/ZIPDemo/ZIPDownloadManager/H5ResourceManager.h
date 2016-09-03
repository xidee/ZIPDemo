//
//  H5ResourceManager.h
//  yintaiwang
//
//  Created by 细 Dee. on 16/7/25.
//  Copyright © 2016年 细 Dee. All rights reserved.
//  H5应用模块资源管理器

#import <Foundation/Foundation.h>

//ZIP下载路径 缓存用
#define H5CachePath [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"ZIPCaChe"]
//ZIP解压路径 持久化用
#define H5ResourcePath [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"H5Resource"]
//H5资源版本信息Plist
#define H5ResourceVersionPlistPath [H5ResourcePath stringByAppendingPathComponent:@"ResourceVersion.plist"]

@interface H5ResourceManager : NSObject

/**
 * 用来标志需要拦截的URL (本地的)
 */
@property (atomic ,strong) NSArray *localArr;

/**
 * 用来标志需要拦截的资源
 */
@property (atomic ,strong) NSArray *manifest;

/**
 *  从公共配置参数里面获取的需要维护的application
 */
@property (atomic ,strong) NSArray *applicationnames;

/**
 * 本地持久化的applicationInfo
 */
@property (atomic ,strong) NSMutableDictionary *applicationInfo;

/**
 * 获取H5资源管理器
 */
+ (instancetype)shared;

/**
 * 更新本地资源
 */
- (void)requestToGetUpgradeInfo;

/**
 * @return 删除本地本地资源结果
 */
- (BOOL)clearLocalH5Resource;

/**
 * @return 资源池大小
 */
- (unsigned long long)getH5ResourceSize;

@end
