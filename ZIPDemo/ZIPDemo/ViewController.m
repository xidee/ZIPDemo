//
//  ViewController.m
//  ZIPDemo
//
//  Created by yanglee on 16/7/21.
//  Copyright © 2016年 细 Dee. All rights reserved.
//

#import "ViewController.h"
#import "AFHTTPSessionManager.h"
#import "SSZipArchive.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UILabel *progressLabel;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.edgesForExtendedLayout =  UIRectEdgeNone;
}

- (IBAction)downloadAction:(UIButton *)sender {
    //tap to download
    AFHTTPSessionManager *manager = [[AFHTTPSessionManager alloc] initWithBaseURL:[NSURL URLWithString:@"http://dev.umeng.com"]];
    NSString *url = @"http://dev.umeng.com/system/resources/W1siZiIsIjIwMTYvMDUvMzAvMTRfMTZfMjJfNjMwX3Vtc2RrX0lPU19hbmFseWljc19pZGZhX3Y0LjAuNC56aXAiXV0/umsdk_IOS_analyics_idfa_v4.0.4.zip";
    //沙盒cache 路径
    NSString *path =  [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
    NSURLSessionDownloadTask *task = [manager downloadTaskWithRequest:request progress:^(NSProgress * _Nonnull downloadProgress) {
        //进度
        dispatch_async(dispatch_get_main_queue(), ^{
            self.progressLabel.text = [NSString stringWithFormat:@"%%%.2f",downloadProgress.fractionCompleted * 100];
        });
    } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
        //返回文件保存路径
        return [NSURL fileURLWithPath:[path stringByAppendingPathComponent:response.suggestedFilename]];
    } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
        if (error) {
            self.progressLabel.text = @"下载失败";
            NSLog(@"errorReson:%@",error.localizedDescription);
        }else{
            //解压
            self.progressLabel.text = @"下载成功，准备解压";
            //构造沙盒路径
            NSString *dPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
            [self unZipWithFilePath:filePath destination:dPath];
        }
    }];
    //默认挂起 需要手动执行
    [task resume];
}

//目标路径 filePath
//解压完存放路径 destination
- (void)unZipWithFilePath:(NSURL *)filePath destination: (NSString *)destination
{
    //这里注意去掉url path的 @"file://" 否则会导致访问失败
    NSString *input = [filePath.absoluteString stringByReplacingOccurrencesOfString:@"file://" withString:@""];
    NSLog(@"输出：%@,写入：%@",input,destination);
    BOOL success = [SSZipArchive unzipFileAtPath:input toDestination:destination];
    if (success) {
        //解压成功 输出目标路径
        self.progressLabel.text = @"解压成功";
        NSLog(@"targetPath:%@",destination);
    }else{
        //解压失败需要删除
        self.progressLabel.text = @"解压失败";
    }
    //不管成功失败都要将ZIP删除（沙盒CACHE）
    [self delZipWithFilePath:input];
}

- (IBAction)delOlderVersionInPath:(UIButton *)sender {
    //构造沙盒路径
    NSString *dPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    //删除解压完的压缩包 这里是写死的 需要拓展成动态的
    NSString *filePath =[[NSString alloc] initWithFormat:@"%@/umsdk_IOS_analyics_idfa_v4.0.4",dPath];
    if ([fileManager removeItemAtPath:filePath error:NULL]) {
        self.progressLabel.text = @"删除解压文件成功";
    }else{
        self.progressLabel.text = @"删除解压文件失败";
    }
}
//删除ZIP
- (void)delZipWithFilePath :(NSString *)path
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager removeItemAtPath:path error:NULL]) {
        self.progressLabel.text = @"删除ZIP成功";
    }else{
        self.progressLabel.text = @"删除ZIP失败";
    }
}

@end
