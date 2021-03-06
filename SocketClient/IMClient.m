//
//  IMClient.m
//  SocketClient
//
//  Created by GCF on 16/7/7.
//  Copyright © 2016年 simple. All rights reserved.
//

#import "IMClient.h"
#import "AsyncSocket.h"
@interface IMClient()
@property(nonatomic,strong)NSTimer *netTimer;
@property(nonatomic,strong)NSTimer *sendTimer;
@property(nonatomic,strong)NSTimer *checkTimer;
@property(nonatomic,assign)NSTimeInterval lastInteval;
@property(nonatomic,strong)ServiceStatusConnectChangedBlock serviceStatusConnectChangedBlock;
@property(nonatomic,strong)OnMessageResponseBlock onMessageResponseBlock;
@end
@implementation IMClient

+(instancetype) shareInstance
{
    static IMClient *sharedInstance = nil;
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        sharedInstance=[[self alloc] init];
    });
    return sharedInstance;
}

-(void)initialize:(SocketConfig *)config serviceStatusConnectChangedBlock:(ServiceStatusConnectChangedBlock)serviceStatusConnectChangedBlock onMessageResponseBlock:(OnMessageResponseBlock) onMessageResponseBlock
{
    self.connect=[[IMConnect alloc]init];
    self.connect.socket.delegate=self;
    self.connect.config=config;
    self.serviceStatusConnectChangedBlock=serviceStatusConnectChangedBlock;
    self.onMessageResponseBlock=onMessageResponseBlock;
}


#pragma AsyncScoket Delagate
- (void)onSocket:(AsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port {
    NSLog(@"onSocket:%p didConnectToHost:%@ port:%hu",sock,host,port);
    if (self.serviceStatusConnectChangedBlock) {
        self.connect.serviceStatus=true;
        self.serviceStatusConnectChangedBlock(1);
    }
    if (self.netTimer) {
        [self.netTimer invalidate];
        self.netTimer=nil;
    }
    if (!self.sendTimer) {
        self.sendTimer=[NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(sendTimerAction) userInfo:nil repeats:YES];
    }
    if (!self.checkTimer) {
        self.checkTimer=[NSTimer scheduledTimerWithTimeInterval:13 target:self selector:@selector(checkTimerAction) userInfo:nil repeats:YES];
    }
    
    [sock readDataWithTimeout:1 tag:0];
}
- (void)onSocket:(AsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    //[sock readDataToData:[AsyncSocket CRLFData] withTimeout:-1 tag:0];  // 这句话仅仅接收\r\n的数据
    [sock readDataWithTimeout: -1 tag: 0];
}

- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    NSString* aStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"Hava received datas is :%@",aStr);
    if (self.onMessageResponseBlock && aStr != nil && aStr != NULL && ![aStr isEqualToString:@"Service-Ping"]) {
        self.onMessageResponseBlock(aStr);
    }
    [aStr release];
    self.lastInteval=[[NSDate date] timeIntervalSince1970];
    [sock readDataWithTimeout:-1 tag:0];
}

- (void)onSocket:(AsyncSocket *)sock didSecure:(BOOL)flag
{
    NSLog(@"onSocket:%p didSecure:YES", sock);
}

- (void)onSocket:(AsyncSocket *)sock willDisconnectWithError:(NSError *)err
{
    NSLog(@"onSocket:%p willDisconnectWithError:%@", sock, err);
}

- (void)onSocketDidDisconnect:(AsyncSocket *)sock
{
    //断开连接了
    NSLog(@"onSocketDidDisconnect:%p", sock);
    if (self.serviceStatusConnectChangedBlock) {
        self.connect.serviceStatus=false;
        self.serviceStatusConnectChangedBlock(0);
    }
    sock = nil;
    if (!self.netTimer) {
        self.netTimer=[NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(netTimerAction) userInfo:nil repeats:YES];
    }
    if (self.sendTimer) {
        [self.sendTimer invalidate];
        self.sendTimer=nil;
    }
    if (self.checkTimer) {
        [self.checkTimer invalidate];
        self.checkTimer=nil;
    }
}

- (void)netTimerAction
{
    [self.connect connect];
}

- (void)sendTimerAction
{
    [self.connect sendMsgToServer:@"Chilent-Ping"];
}

- (void)checkTimerAction
{
    NSTimeInterval interval=[[NSDate date]timeIntervalSinceDate:[NSDate dateWithTimeIntervalSince1970:self.lastInteval]];
    if (interval>13) {
        [self.connect disconnect];
    }
}


@end



@implementation IMConnect

- (instancetype)init
{
    self=[super init];
    if (self) {
        self.serviceStatus=false;
        self.socket=[AsyncSocket new];
    }
    return self;
}

-(void)disconnect{
    [self.socket disconnect];
}

-(void)connect
{
    if (!self.serviceStatus) {
        NSError *error=nil;
        [self.socket connectToHost:self.config.host onPort:self.config.port error:&error];
    }
}

-(void)sendMsgToServer:(NSString *)msg
{
    msg = [msg stringByAppendingString:@"\n"];
    if (self.serviceStatus) {
        [self.socket writeData:[msg dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
    }else{
        NSLog(@"连接断开了");
    }
}


@end




@implementation SocketConfig

@end
