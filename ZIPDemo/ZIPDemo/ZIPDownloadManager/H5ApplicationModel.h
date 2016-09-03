//
//  H5ApplicationModel.h
//  yintaiwang
//
//  Created by 细 Dee. on 16/7/25.
//  Copyright © 2016年 细 Dee. All rights reserved.
//  H5应用模块模型

#import <Foundation/Foundation.h>

@interface H5ApplicationModel : NSObject
/**
 * 应用名称
 */
@property (nonatomic ,copy) NSString *name;
/**
 * 客户端应用模块的当前版本
 */
@property (nonatomic ,copy) NSString *version;
/**
 * 客户端应用模块的根目录
 */
@property (nonatomic ,copy) NSString *applicationRootDir;

@end
