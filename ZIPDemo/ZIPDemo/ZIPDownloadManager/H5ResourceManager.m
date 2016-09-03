//
//  H5ResourceManager.m
//  yintaiwang
//
//  Created by 细 Dee. on 16/7/25.
//  Copyright © 2016年 细 Dee. All rights reserved.
//

#import "H5ResourceManager.h"
#import "H5UpgradeInfoModel.h"
#import "H5ResourceModel.h"
#import "SSZipArchive.h"
#import "H5ApplicationModel.h"
#import "AFNetworking.h"
#import "NSDataAdditions.h"
#import "NSObject+MJKeyValue.h"

//json文件的名称
NSString * const JsonFile = @"manifest.json";

#define TrashPath [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"TrashPath"]
/**
 *  格式化log输出
 *  msg: log信息
 *  target: 目标
 *  reson：错误原因 could be nil
 */
#define H5ResourceManagerLog(a,b,c) NSLog(@"H5ResourceManager Log:msg:%@ target:%@ reson:%@",a,b,c)

@interface H5ResourceManager ()

/**
 *  用来管理下载任务的池子-(仅wifi下载)
 */
@property (atomic ,strong) NSMutableArray *WiFiOnlyTaskPool;
/**
 *  用来管理下载任务的池子-(非WIFI也必须下载的任务)
 */
@property (atomic ,strong) NSMutableArray *necessaryTaskPool;

@end

@implementation H5ResourceManager

#pragma mark - public (公开的API)
+ (instancetype)shared
{
    static H5ResourceManager *instance ;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
        instance.applicationInfo =  [NSMutableDictionary dictionaryWithDictionary:[instance getApplicationInfoPlist]];
    });
    return instance;
}

/**
 *  删除整个H5资源池
 *  @return 删除结果
 */
- (BOOL)clearLocalH5Resource
{
    [self.applicationInfo removeAllObjects];
    return [[NSFileManager defaultManager] removeItemAtPath:H5ResourcePath error:NULL];
}

/**
 * @return 获取资源池大小
 */
- (unsigned long long)getH5ResourceSize
{
    return [self folderSizeAtPath:H5ResourcePath];
}

/**
 *  执行更新检查
 */
- (void)requestToGetUpgradeInfo
{
    [self redirectNSlogToDocumentFolder];
    //清除上次的数据
    [self clearDataBeferUpdate];
    
    //循环拿到本地的applications
    NSMutableArray *appArr = [[NSMutableArray alloc] init];
    for (NSString *appName in self.applicationnames) {
        H5ApplicationModel *appModel;
        NSDictionary *appDic = [self.applicationInfo objectForKey:appName];
        if (appDic) {
//            appModel = [H5ApplicationModel objectWithKeyValues:appDic];
        }else{
            //本地没有改app 版本初始化为空
            appModel = [[H5ApplicationModel alloc] init];
            appModel.name = appName;
            appModel.version = @"";
        }
        //YTOauthManager 没处理 需要手动处理成字典
        NSDictionary *app = @{@"name":appModel.name,@"version":appModel.version};
        [appArr addObject:app];
    }
    //请求接口获取更新资源
//    if (appArr.count) {
//        [[YTOauthManager shared] requestWithUrl:IPTypeH5Resource type:PathTypeH5ResourceList params:@[appArr] success:^(id data) {
//            if (data && ![data isKindOfClass:[NSNull class]] && [data respondsToSelector:@selector(objectAtIndex:)])
//            {
//                H5ResourceManagerLog(@"获取更新列表成功", @"", data);
//                 //获得需要更新的模块list
//                NSMutableArray *upgardeInfoList = [[NSMutableArray alloc] init];
//                for (NSDictionary *upgardeInfo in data) {
//                    H5UpgradeInfoModel *infoModel = [H5UpgradeInfoModel objectWithKeyValues:upgardeInfo];
//                    [upgardeInfoList addObject:infoModel];
//                }
//                [self activateConcurrentThreadWithUpgardeInfoList:upgardeInfoList];
//       
//    }
}

#pragma mark - private (私有API)
/**
 *  请求资源更新之前的数据处理
 */
- (void)clearDataBeferUpdate
{
    //每次请求更新之前清空回收站
    if ([[NSFileManager defaultManager] fileExistsAtPath:TrashPath]) {
        [self removeOrClear:NO atPath:TrashPath];
    }
    //清空临时目录
    if ([[NSFileManager defaultManager] fileExistsAtPath:H5CachePath]) {
        [self removeOrClear:NO atPath:H5CachePath];
    }

    //比对服务端返回的appnames 和本地的 删除本地多余的
    if (self.applicationnames.count) {        
        NSMutableArray *delNames = [[NSMutableArray alloc] init];
        for (NSString *key in self.applicationInfo.allKeys) {
            NSDictionary *dic = [self.applicationInfo objectForKey:key];
            BOOL has = NO;
            for (NSString *name in self.applicationnames) {
                if ([key isEqualToString:name]) {
                    //匹配 跳出内循环
                    has = YES;
                    break;
                }
            }
            //本地有 但是服务端返回的没有
            if (!has) {
                [delNames addObject:dic];
            }
        }
        //删除所有服务端没有的
        for (NSDictionary *dic in delNames) {
            NSString * name = [dic objectForKey:@"name"];
            NSString *appRoot = [dic objectForKey:@"applicationRootDir"];
            [self clearResourceVersion:name];
            [self removeOrClear:YES atPath:[H5ResourcePath stringByAppendingPathComponent:appRoot]];
        }
    }else{
        //直接清空资源池
        [self.applicationInfo removeAllObjects];
        [self removeOrClear:NO atPath:H5ResourcePath];
    }
    H5ResourceManagerLog(@"更新前维护本地版本与资源池完成", @"", @"");
}

/*
 *  @return 返回资源版本plist文件
 */
- (NSDictionary *)getApplicationInfoPlist
{
    //先取资源根目录 不存在要创建
    NSError *error;
    if (![[NSFileManager defaultManager]fileExistsAtPath:H5ResourcePath]) {
        if (![[NSFileManager defaultManager] createDirectoryAtPath:H5ResourcePath withIntermediateDirectories:YES attributes:nil error:&error]) {
            H5ResourceManagerLog(@"创建资源根目录失败",H5ResourcePath,error.localizedDescription);
            return nil;
        }
    }
    //判断是否存在版本plist文件
    if (![[NSFileManager defaultManager]fileExistsAtPath:H5ResourceVersionPlistPath]) {
        //创建plist
        if (![[NSFileManager defaultManager] createFileAtPath:H5ResourceVersionPlistPath contents:nil attributes:nil]) {
            H5ResourceManagerLog(@"创建版本plist文件失败",H5ResourceVersionPlistPath,error.localizedDescription);
            return nil;
        }
        //写入一个空的DIC
        NSDictionary *dic = [[NSDictionary alloc] init];
        if (![dic writeToFile:H5ResourceVersionPlistPath atomically:YES]) {
            return nil;
        }
    }
    return [NSDictionary dictionaryWithContentsOfFile:H5ResourceVersionPlistPath];
}

/*
 *  更新本地应用版本信息
 *  @return 返回更新操作结果
 *  @parma appModel 需要写入的应用信息
 */
- (BOOL)updateResourceVersion :(H5ApplicationModel *)appModel
{
    @synchronized (self.applicationInfo) {
        [self.applicationInfo setValue:[appModel keyValues] forKey:appModel.name];
    }
    return [self.applicationInfo writeToFile:H5ResourceVersionPlistPath atomically:YES];
}

/*
 *  清楚本地应用版本信息
 *  @return 返回操作结果
 *  @parma appName 需要清楚的应用名称
 */
- (BOOL)clearResourceVersion :(NSString *)appName
{
    @synchronized (self.applicationInfo) {
        if ([self.applicationInfo.allKeys containsObject:appName]) {
            [self.applicationInfo removeObjectForKey:appName];
        }else{
            return YES;
        }
    }
    return [self.applicationInfo writeToFile:H5ResourceVersionPlistPath atomically:YES];
}

/**
 * 并发的启动每个application更新
 * @parma upgardeInfoList 需要更新的模块列表
 */
- (void)activateConcurrentThreadWithUpgardeInfoList :(NSArray *)upgardeInfoList
{
    if(!upgardeInfoList.count){
        return;
    }
    //创建缓存根目录
    if (![[NSFileManager defaultManager] fileExistsAtPath:H5CachePath]) {
        NSError *error;
        if (![[NSFileManager defaultManager] createDirectoryAtPath:H5CachePath withIntermediateDirectories:YES attributes:nil error:&error]) {
            H5ResourceManagerLog(@"创建缓存根目录失败", H5CachePath, error.localizedDescription);
            return;
        }
    }
    //创建一个并发队列 几个模块 几个并发
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    //设置最大并发数
    queue.maxConcurrentOperationCount = upgardeInfoList.count;
    //开启网络监听
    [self monitorNetworkStatus];
    
    for (H5UpgradeInfoModel *infoModel in upgardeInfoList) {
        //添加并发任务
        [queue addOperationWithBlock:^{
            [self requestWithArray:infoModel index:0];
            H5ResourceManagerLog(@"开启下载队列", infoModel.application, @"");
        }];
    }
}

/**
 *  串行递归 每个任务队列里 one by one 执行
 *  @Parma infoModel 更新的模块信息
 *  @Parma 更新包index
 */
- (void)requestWithArray:(H5UpgradeInfoModel *)infoModel index:(NSInteger)index
{
    //下标超出 则跳出
    if (index >= infoModel.resources.count){
        return;
    }
    
    H5ResourceModel *resModel = [infoModel.resources objectAtIndex:index];
    //构造下载
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:resModel.downloadUrl]];
    __block NSURLSessionDownloadTask *task = [manager downloadTaskWithRequest:request progress:^(NSProgress * _Nonnull downloadProgress) {
        //进度
        NSString *progress = [NSString stringWithFormat:@"%@,%@%f",infoModel.application,resModel.applicationVersion,downloadProgress.fractionCompleted];
        H5ResourceManagerLog(@"下载进度",progress,@"");
    } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
        //zip包的缓存目录（在suggestedFilename基础上拼上 应用名+版本 防止命名重复）
        return [NSURL fileURLWithPath:[H5CachePath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@%@%@",infoModel.application,resModel.applicationVersion,response.suggestedFilename]]];
    } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error)
    {
        //下载完成
        [self task:task didCompleteWithInfoModel:infoModel index:index filePath:filePath error:error];
    }];
    
    //任务创建完成 激活
    [self taskAction:task withResMoedl:resModel];
    H5ResourceManagerLog(@"创建任务",infoModel.application,resModel.applicationVersion);
}

/**
 *  重启未完成的下载 (重启的任务全部直接添加到管理池，网络允许之后再下载)
 *  @Parma infoModel 对应的更新模块
 *  @Parma index 更新包的index
 */
- (void)resumeDownloadWithError :(NSError *)err InfoMdoel :(H5UpgradeInfoModel *)infoModel Index:(NSUInteger )index
{
    NSData *resumeData = [err.userInfo objectForKey:NSURLSessionDownloadTaskResumeData];
    if (!resumeData || index >= infoModel.resources.count) {
        return;
    }
    H5ResourceModel *resModel  = [infoModel.resources objectAtIndex:index];
    __block NSURLSessionDownloadTask *task = [[AFHTTPSessionManager manager] downloadTaskWithResumeData:resumeData progress:^(NSProgress * _Nonnull downloadProgress) {
        //进度
        NSString *progress = [NSString stringWithFormat:@"%@,%@%f",infoModel.application,resModel.applicationVersion,downloadProgress.fractionCompleted];
        H5ResourceManagerLog(@"重启任务下载进度",progress,@"");
    } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
        //zip包的缓存目录（在suggestedFilename基础上拼上 当前时间 防止命名重复）
        return [NSURL fileURLWithPath:[H5CachePath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@%@%@",infoModel.application,resModel.applicationVersion,response.suggestedFilename]]];
    } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error){
        //下载完成
        [self task:task didCompleteWithInfoModel:infoModel index:index filePath:filePath error:error];
    }];

    //任务创建完成 激活
    [self taskAction:task withResMoedl:resModel];
    H5ResourceManagerLog(@"重启未完成任务",infoModel.application,resModel.applicationVersion);
}

/**
 *  任务创建完成后根据网络环境判断是否激活
 *  @parma task 下载任务
 *  @parma resModel zip包模型
 */
- (void)taskAction:(NSURLSessionDownloadTask *)task withResMoedl:(H5ResourceModel *)resModel
{
    //根据任务的类型加入对应的任务管理池 (服务端标示)
    if (resModel.isMeterDownLoad) {
        @synchronized (self.necessaryTaskPool) {
            if (!self.necessaryTaskPool) {
                self.necessaryTaskPool = [[NSMutableArray alloc] init];
            }
            [self.necessaryTaskPool addObject:task];
        }
    }else{
        @synchronized (self.WiFiOnlyTaskPool) {
            if (!self.WiFiOnlyTaskPool) {
                self.WiFiOnlyTaskPool = [[NSMutableArray alloc] init];
            }
            [self.WiFiOnlyTaskPool addObject:task];
        }
    }
    //根据任务类型以及网络环境判断开不开启任务
    switch ([AFNetworkReachabilityManager sharedManager].networkReachabilityStatus) {
        case AFNetworkReachabilityStatusReachableViaWiFi:
        {   //wifi
            [task resume];
            H5ResourceManagerLog(@"下载启动", resModel.downloadUrl, @"");
        }
            break;
        case AFNetworkReachabilityStatusReachableViaWWAN:
        {   //蜂窝
            if (resModel.isMeterDownLoad)
            {
                [task resume];
                H5ResourceManagerLog(@"下载启动", resModel.downloadUrl, @"");
            }
        }
            break;
        default:
            break;
    }
}

/**
 *  下载完成后的逻辑处理
 *  @Parma task 下载任务
 *  @Parma infoModel 对应的更新模块
 *  @Parma index 更新包的index
 *  @Parma filePath 下载完成的zip包路径
 *  @Parma error 错误信息
 */
- (void)task:(NSURLSessionDownloadTask *)task didCompleteWithInfoModel :(H5UpgradeInfoModel *)infoModel index:(NSUInteger)index filePath:(NSURL *)filePath error:(NSError *)error
{
    //从任务管理池子中移除
    @synchronized (self.necessaryTaskPool) {
        if ([self.necessaryTaskPool containsObject:task]) {
            [self.necessaryTaskPool removeObject:task];
        }
    }
    @synchronized (self.WiFiOnlyTaskPool) {
        if ([self.WiFiOnlyTaskPool containsObject:task]) {
            [self.WiFiOnlyTaskPool removeObject:task];
        }
    }
    if (error){
        //仅当网络丢失时候 重启任务
        H5ResourceModel *resModel = [infoModel.resources objectAtIndex:index];
        NSString * des = [NSString stringWithFormat:@"%@%@",infoModel.application,resModel.applicationVersion];
        H5ResourceManagerLog(@"任务下载失败", des, error.localizedDescription);
        if (error.code == NSURLErrorNetworkConnectionLost) {
            [self resumeDownloadWithError:error InfoMdoel:infoModel Index:index];
        }
    }else{
        //校验数据
        [self verifyDataWithInfoModel:infoModel Index:index FilePath:filePath];
    }
}

/**
 *  监听网络状态 (启用AFNETWorking 网络环境监听)
 */
- (void)monitorNetworkStatus
{
    AFNetworkReachabilityManager *netManager = [AFNetworkReachabilityManager sharedManager];
    [netManager setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        switch (status) {
            case AFNetworkReachabilityStatusReachableViaWWAN:
                H5ResourceManagerLog(@"已切换为蜂窝网络",@"", @"");
                @synchronized (self.WiFiOnlyTaskPool) {
                    //暂停下载的wifi任务
                    for (NSURLSessionDownloadTask *task in self.WiFiOnlyTaskPool) {
                        if (task.state == NSURLSessionTaskStateRunning) {
                            H5ResourceManagerLog(@"下载任务暂停", task.currentRequest.URL.absoluteString, @"");
                            [task suspend];
                        }
                    }
                }
                @synchronized (self.necessaryTaskPool) {
                    //开启暂停的蜂窝任务
                    for (NSURLSessionDownloadTask *task in self.necessaryTaskPool) {
                        if (task.state == NSURLSessionTaskStateSuspended) {
                            H5ResourceManagerLog(@"下载任务启动", task.currentRequest.URL.absoluteString, @"");
                            [task resume];
                        }
                    }
                }
                break;
                
            case AFNetworkReachabilityStatusReachableViaWiFi:
                H5ResourceManagerLog(@"已切换为WIFI网络",@"", @"");
                @synchronized (self.WiFiOnlyTaskPool) {
                    //开启暂停的wifi任务
                    for (NSURLSessionDownloadTask *task in self.WiFiOnlyTaskPool) {
                        if (task.state == NSURLSessionTaskStateSuspended) {
                            H5ResourceManagerLog(@"下载任务启动", task.currentRequest.URL.absoluteString, @"");
                            [task resume];
                        }
                    }
                }
                @synchronized (self.necessaryTaskPool) {
                    //开启暂停的蜂窝任务
                    for (NSURLSessionDownloadTask *task in self.necessaryTaskPool) {
                        if (task.state == NSURLSessionTaskStateSuspended) {
                            H5ResourceManagerLog(@"下载任务启动", task.currentRequest.URL.absoluteString, @"");
                            [task resume];
                        }
                    }
                }
                break;
            default:
                break;
        }
    }];
    //开启监听
    [netManager startMonitoring];
}

/**
 * 校验下载完成的数据
 * @Parma infoModel 更新模块信息
 * @Parma index 更新包index
 * @Parma filePath zip存放路径
 */
- (void)verifyDataWithInfoModel:(H5UpgradeInfoModel *)infoModel Index:(NSUInteger)index FilePath:(NSURL *)filePath
{
    //下标超出 则跳出
    if (index >= infoModel.resources.count){
        return;
    }
    H5ResourceModel *resModel = [infoModel.resources objectAtIndex:index];
    //解压(路径为 根目录/应用名称+资源包版本)
    NSString *unzipPath = [H5CachePath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@%@",infoModel.application,resModel.applicationVersion]];
    //校验文件大小
    if (![self checkFileSizeAtPath:filePath.path size:resModel.size]) {
        return;
    }
    
    if (![self unZipWithFilePath:filePath.path destination:unzipPath]) {
        return;
    }
    H5ResourceManagerLog(@"解压完成", unzipPath, @"");
    
    NSString *jsonFilePath = [[unzipPath stringByAppendingPathComponent:infoModel.applicationRootDir] stringByAppendingPathComponent:JsonFile];
    //遍历文件哈希
    if (![self checkJsonDataWithPath:unzipPath andJsonFilePath:jsonFilePath]) {
        [self moveItemToTrashWithPath:unzipPath];
        return;
    }
    H5ResourceManagerLog(@"文件哈希校验完成", unzipPath, @"");
    
    //创建项目根目录
    NSError *error;
    NSString *docPath = [H5ResourcePath stringByAppendingPathComponent:infoModel.applicationRootDir];
    if (![[NSFileManager defaultManager] fileExistsAtPath:docPath]) {
        if (![[NSFileManager defaultManager] createDirectoryAtPath:docPath withIntermediateDirectories:YES attributes:nil error:&error]) {
            H5ResourceManagerLog(@"创建应用根目录失败", docPath,error.localizedDescription);
            return;
        }
    }

    //全量直接操作整个根目录 这里move（rename）的是 host的下一级path
    if (infoModel.isWhole) {
        NSError *error;
        //清除版本信息
        if (![self clearResourceVersion:infoModel.application]) {
            H5ResourceManagerLog(@"清除版本信息失败", infoModel.application,@"");
            return;
        }
        //将原应用移除
        if (![self moveItemToTrashWithPath:docPath]) {
            //失败一次 三秒后重试 （将线程暂停三秒）
            [NSThread sleepForTimeInterval:3];
            H5ResourceManagerLog(@"重试rename", infoModel.application,@"");
            if (![self moveItemToTrashWithPath:docPath]) {
                return;
            }
        }
        //全量更新直接移动
        if (![[NSFileManager defaultManager] moveItemAtPath:[unzipPath stringByAppendingPathComponent:infoModel.applicationRootDir] toPath:docPath error:&error]) {
            H5ResourceManagerLog(@"全量更新覆盖失败",docPath,error);
            //移动失败 暂停线程3秒 重试
            [NSThread sleepForTimeInterval:3];
            H5ResourceManagerLog(@"重试全量move",docPath,@"");
             if (![[NSFileManager defaultManager] moveItemAtPath:[unzipPath stringByAppendingPathComponent:infoModel.applicationRootDir] toPath:docPath error:&error])
             {
                 H5ResourceManagerLog(@"全量更新覆盖失败",docPath,error);
                 return;
             }
        }
        H5ResourceManagerLog(@"全量更新覆盖成功",docPath,resModel.applicationVersion);
    }else{
        //遍历覆盖
        if (![self coverItem:[unzipPath stringByAppendingPathComponent:infoModel.applicationRootDir] toNewFolder:docPath]) {
            return;
        }
        H5ResourceManagerLog(@"增量更新覆盖成功",docPath,resModel.applicationVersion);
    }

    //更新本地版本号
    H5ApplicationModel *appModel = [[H5ApplicationModel alloc] init];
    appModel.name = infoModel.application;
    appModel.version = resModel.applicationVersion;
    appModel.applicationRootDir = infoModel.applicationRootDir;
    if (![self updateResourceVersion:appModel]) {
        H5ResourceManagerLog(@"更新本地版本号失败",infoModel.application,resModel.applicationVersion);
        return;
    }
    H5ResourceManagerLog(@"更新本地版本号成功",infoModel.application,resModel.applicationVersion);
    //覆盖成功之后再执行下次下载
    [self requestWithArray:infoModel index:index+1];
}

/**
 *  校验文件大小
 *  @parma path 文件路径
 *  @parma size 文件大小
 */
- (BOOL)checkFileSizeAtPath :(NSString *)path size:(NSUInteger)size
{
    NSError *error;
    //获取目录属性信息
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:&error];
    if (error || !attributes) {
        H5ResourceManagerLog(@"获取ZIP目录信息失败", path, error.localizedDescription);
        //获取目录信息失败移除zip
        [self moveItemToTrashWithPath:path];
        return NO;
    }
    if (attributes.fileSize != size) {
        H5ResourceManagerLog(@"ZIP包大小不匹配", path, error.localizedDescription);
        //大小失败删除zip
        [self moveItemToTrashWithPath:path];
        return NO;
    }
    H5ResourceManagerLog(@"ZIP包大小匹配", path,@"");
    return YES;
}

/**
 *  解压 ZIP 的方法
 *  @parma filePath ZIP文件路径
 *  @parma destination 目标路径
 *  @return 操作结果
 */
- (BOOL)unZipWithFilePath:(NSString *)filePath destination: (NSString *)destination
{
    @try {
        BOOL unzip = [SSZipArchive unzipFileAtPath:filePath toDestination:destination];
        if (!unzip) {
            H5ResourceManagerLog(@"解压失败",filePath, @"");
        }
        return unzip;
    } @catch (NSException *exception) {
        H5ResourceManagerLog(@"解压失败",filePath, @"");
        return NO;
    } @finally {
        //解压无论成功失败 删除ZIP包
        [self moveItemToTrashWithPath:filePath];
    }
}

/**
 *  遍历校验manifest.json
 *  @parma jsonPath json文件路径
 *  @parma path 需要遍历的应用地址
 *  @return 校验结果
 */
- (BOOL)checkJsonDataWithPath:(NSString *)path andJsonFilePath :(NSString *)jsonPath
{
    NSData *jsonData = [NSData dataWithContentsOfFile:jsonPath];
    if (jsonData) {
        NSError *error;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:&error];
        if (json && !error) {
            NSDictionary *contentHash = [json objectForKey:@"contentHash"];
            if (contentHash && [contentHash isKindOfClass:[NSDictionary class]]) {
                for (NSString *key in contentHash.allKeys) {
                    if (![self checkHashWithPath:[path stringByAppendingPathComponent:key] andHashString:[contentHash objectForKey:key]]) {
                        return NO;
                    }
                }
                return YES;
            }
        }
    }
    H5ResourceManagerLog(@"读取json文件失败",jsonPath,@"");
    return NO;
}

/**
 *  校验HASH 的方法
 *  @parma path 需要校验的文件路径
 *  @parma Hash 哈希值
 *  @return 操作结果
 */
- (BOOL)checkHashWithPath :(NSString *)path andHashString :(NSString *)Hash
{
    NSData *data = [NSData dataWithContentsOfFile:path];
    //匹配哈希
    BOOL isMatch = [data.md5Hash isEqualToString:Hash];
    if (!isMatch) {
        H5ResourceManagerLog(@"文件哈希不匹配",path,Hash);
    }
    return isMatch;
}

/**
 *  覆盖方法
 *  @parma folder 要覆盖的文件目录
 *  @parma newFolder 被覆盖的文件目录
 *  @return 操作结果
 */
- (BOOL)coverItem :(NSString *)folder toNewFolder :(NSString *)newFolder
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSError *error;
    BOOL isDirectory;
    if (![fileManager fileExistsAtPath:folder isDirectory:&isDirectory]) {
        H5ResourceManagerLog(@"增量覆盖获取目录失败",folder,@"");
        return NO;
    }
    
    if (isDirectory) {
        //是目录 判断目标路径存不存在该目录
        if (![fileManager fileExistsAtPath:newFolder]) {
            //不存在就创建
            if (![fileManager createDirectoryAtPath:newFolder withIntermediateDirectories:YES attributes:nil error:&error]) {
                H5ResourceManagerLog(@"增量覆盖创建目标目录失败",newFolder,error.localizedDescription);
                return NO;
            }
        }
        
        NSArray *fileList = [fileManager contentsOfDirectoryAtPath:folder error:&error];
        if (error || !fileList) {
            H5ResourceManagerLog(@"增量覆盖获取子目录失败",folder,error.localizedDescription);
            return NO;
        }
        //遍历取二级目录
        for (NSString *fileName in fileList) {
            //构造覆盖地址 和被覆盖地址
            NSString *cachePath = [folder stringByAppendingPathComponent:fileName];
            NSString *targetPath = [cachePath stringByReplacingOccurrencesOfString:folder withString:newFolder];
            //递归继续遍历
            if (![self coverItem:cachePath toNewFolder:targetPath]) {
                return NO;
            }
        }
    }else{
        //是文件
        if ([fileManager fileExistsAtPath:newFolder]) {
            //而且目标文件存在 则删除
            if (![self moveItemToTrashWithPath:newFolder]) {
                return NO;
            }
        }
        //移动到目标位置
        if (![fileManager moveItemAtPath:folder toPath:newFolder error:&error]) {
            //暂停 三秒 重试
            [NSThread sleepForTimeInterval:3];
            if (![fileManager moveItemAtPath:folder toPath:newFolder error:&error]) {
                H5ResourceManagerLog(@"增量覆盖文件失败",newFolder,error.localizedDescription);
                return NO;
            }
        }
    }
    return YES;
}

/**
 *  移动文件/文件夹 到回收站（TrashPath）目录
 *  @parma 要操作的文件/文件夹路径
 *  @return 操作结果
 */
- (BOOL)moveItemToTrashWithPath:(NSString*)path
{
    NSError *error;
    //如果不存在TrashPath 则创建
    if (![[NSFileManager defaultManager] fileExistsAtPath:TrashPath]) {
        if (![[NSFileManager defaultManager] createDirectoryAtPath:TrashPath withIntermediateDirectories:YES attributes:nil error:&error]) {
            H5ResourceManagerLog(@"创建回收站失败",TrashPath,error.localizedDescription);
            return NO;
        }
    }
    //目标路径为 TrashPath/item名称+当前时间 防止重名
    NSString *target = [TrashPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@%@",path.lastPathComponent,[NSDate date]]];
    if (![[NSFileManager defaultManager] moveItemAtPath:path toPath:target error:&error]) {
        H5ResourceManagerLog(@"移动文件到回收站失败", path,error.localizedDescription);
        return NO;
    }
    H5ResourceManagerLog(@"移除文件到回收站", path,@"");
    return YES;
}

/**
 *  删除文件/文件夹
 *  @parma isRemove 删除目录/文件传 YES，清空目录传NO
 *  @parma path 要操作的目录
 *  @return 操作结果
 */
- (BOOL)removeOrClear :(BOOL)isRemove atPath :(NSString *)path
{
    NSError *error;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (isRemove) {
        //删除目录/文件
        if (![fileManager removeItemAtPath:path error:&error]) {
            H5ResourceManagerLog(@"清空文件/文件夹失败", path,error.localizedDescription);
            return NO;
        }
    }else{
        NSArray *fileList = [fileManager contentsOfDirectoryAtPath:path error:&error];
        if (error) {
            H5ResourceManagerLog(@"清空文件/文件夹失败", path,error.localizedDescription);
            return NO;
        }
        for (NSString *fileName in fileList) {
            //删除目录里的 文件/文件夹
            if (![fileManager removeItemAtPath:[path stringByAppendingPathComponent:fileName] error:&error]) {
                H5ResourceManagerLog(@"清空文件/文件夹失败", path,error.localizedDescription);
                return NO;
            }
        }
    }
    H5ResourceManagerLog(@"清空文件/文件夹成功", path, @"无");
    return YES;
}

/**
 *  @Parma folderPath 指定路径
 *  @return 获取指定路径 文件/文件夹 的大小
 */
- (unsigned long long) folderSizeAtPath:(NSString *) folderPath{
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    //判断是否目录
    BOOL isDirectory;
    if (![fileManager fileExistsAtPath:folderPath isDirectory:&isDirectory]) {
        H5ResourceManagerLog(@"获取大小失败",folderPath,@"目录不存在");
        return 0;
    }
    
    long long fileSize = 0;
    if (isDirectory){
        //是目录 遍历 取里面的子路径 递归此方法
        NSArray *fileList = [fileManager contentsOfDirectoryAtPath:folderPath error:&error];
        for (NSString *subPath in fileList) {
            fileSize += [self folderSizeAtPath:[folderPath stringByAppendingPathComponent:subPath]];
        }
    }else{
        //是文件 直接加
        fileSize += [fileManager attributesOfItemAtPath:folderPath error:&error].fileSize;
    }
    return fileSize;
}

/**
 *  持久化log信息
 */
- (void)redirectNSlogToDocumentFolder
{
    //如果已经连接Xcode调试则不输出到文件
    if(isatty(STDOUT_FILENO)) {
        return;
    }
    //在模拟器不保存到文件中
    UIDevice *device = [UIDevice currentDevice];
    if([[device model] hasSuffix:@"Simulator"]){
        return;
    }
    
    //将NSlog打印信息保存到Document目录下的Log文件夹下
    NSString *logDirectory = [H5ResourcePath stringByAppendingPathComponent:@"Log"];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:logDirectory]) {
        [fileManager createDirectoryAtPath:logDirectory  withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"zh_CN"]];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"]; //每次启动后都保存一个新的日志文件中
    NSString *dateStr = [formatter stringFromDate:[NSDate date]];
    NSString *logFilePath = [logDirectory stringByAppendingFormat:@"/%@.log",dateStr];
    
    // 将log输入到文件
    freopen([logFilePath cStringUsingEncoding:NSASCIIStringEncoding], "a+", stdout);
    freopen([logFilePath cStringUsingEncoding:NSASCIIStringEncoding], "a+", stderr);
}

@end
