//
//  WxMomentViewController.m
//  照片选择器
//
//  Created by 洪欣 on 2020/8/4.
//  Copyright © 2020 洪欣. All rights reserved.
//

#import "WxMomentViewController.h"
#import "WxMomentHeaderView.h"
#import "HXPhotoPicker.h"
#import "HXPhotoCustomNavigationBar.h"
#import "WxMomentPublishViewController.h"
#import "WxMomentViewCell.h"

@interface WxMomentViewController ()<UITableViewDataSource, UITableViewDelegate, HXCustomCameraViewControllerDelegate, HXCustomNavigationControllerDelegate>
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) WxMomentHeaderView *headerView;
@property (strong, nonatomic) HXPhotoCustomNavigationBar *customNavBar;
@property (strong, nonatomic) UINavigationItem *navItem;
@property (strong, nonatomic) HXPhotoManager *photoManager;
@property (strong, nonatomic) CAGradientLayer *topMaskLayer;
@property (strong, nonatomic) UIView *topView;
@property (assign, nonatomic) BOOL getLocalCompletion;
@end

@implementation WxMomentViewController

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
#ifdef __IPHONE_13_0
    if (@available(iOS 13.0, *)) {
        [self preferredStatusBarUpdateAnimation];
        [self changeStatus];
    }
#endif
}
- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent animated:YES];
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
    [self.navigationController setNavigationBarHidden:YES animated:YES];
}
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:YES];
}
- (void)changeStatus {
#ifdef __IPHONE_13_0
    if (@available(iOS 13.0, *)) {
        if (UITraitCollection.currentTraitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent animated:YES];
            return;
        }
    }
#endif
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent animated:YES];
}

- (HXPhotoManager *)photoManager {
    if (!_photoManager) {
        _photoManager = [[HXPhotoManager alloc] initWithType:HXPhotoManagerSelectedTypePhotoAndVideo];
        _photoManager.configuration.type = HXConfigurationTypeWXMoment;
        _photoManager.configuration.localFileName = @"hx_WxMomentPhotoModels";
    }
    return _photoManager;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.navigationController.interactivePopGestureRecognizer.delegate = (id)self;
    self.title = nil;
    self.view.backgroundColor = [UIColor whiteColor];
#ifdef __IPHONE_13_0
    if (@available(iOS 13.0, *)) {
        self.view.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor hx_colorWithHexStr:@"#191918"];
            }
            return UIColor.whiteColor;
        }];
    }
#endif
    [self.view addSubview:self.topView];
    [self.view addSubview:self.customNavBar];
    // 获取保存在本地文件中的模型数组
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.photoManager getLocalModelsInFile];
        self.getLocalCompletion = YES;
    });
#ifdef __IPHONE_11_0
    if (@available(iOS 11.0, *)) {
        self.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
#else
    if ((NO)) {
#endif
    } else {
        self.automaticallyAdjustsScrollViewInsets = NO;
    }
    self.tableView.tableHeaderView = self.headerView;
        [self.tableView registerNib:[UINib nibWithNibName:NSStringFromClass([WxMomentViewCell class]) bundle:nil] forCellReuseIdentifier:@"WxMomentViewCellId"];
}
- (void)backClick {
    [self.navigationController popViewControllerAnimated:YES];
}
- (void)didNavItemClick {
    if (!self.getLocalCompletion) {
        [self.photoManager getLocalModelsInFile];
    }
    if (self.photoManager.localModels.count) {
        // 有保存草稿的数据，将草稿数据添加后直接跳转
        [self.photoManager addLocalModels];
        [self setupManagerConfig];
        [self presentMomentPublish];
        return;
    }
    HXPhotoBottomViewModel *model1 = [[HXPhotoBottomViewModel alloc] init];
    model1.title = [NSBundle hx_localizedStringForKey:@"拍摄"];
    model1.subTitle = [NSBundle hx_localizedStringForKey:@"照片或视频"];
    model1.subTitleDarkColor = [UIColor hx_colorWithHexStr:@"#999999"];
    model1.cellHeight = 65.f;
    
    HXPhotoBottomViewModel *model2 = [[HXPhotoBottomViewModel alloc] init];
    model2.title = [NSBundle hx_localizedStringForKey:@"从手机相册选择"];
    HXWeakSelf
    [HXPhotoBottomSelectView showSelectViewWithModels:@[model1, model2] headerView:nil cancelTitle:nil selectCompletion:^(NSInteger index, HXPhotoBottomViewModel * _Nonnull model) {
        [weakSelf setupManagerConfig];
        // 去掉dismiss的动画方便选择完成后present
        weakSelf.photoManager.selectPhotoFinishDismissAnimated = NO;
        weakSelf.photoManager.cameraFinishDismissAnimated = NO;
        if (index == 0) {
            [weakSelf hx_presentCustomCameraViewControllerWithManager:weakSelf.photoManager delegate:weakSelf];
        }else if (index == 1){
            [weakSelf hx_presentSelectPhotoControllerWithManager:weakSelf.photoManager delegate:weakSelf];
        }
    } cancelClick:nil];
}
- (void)setupManagerConfig {
    // 因为公用的同一个manager所以这些需要在跳转前设置一下
    self.photoManager.type = HXPhotoManagerSelectedTypePhotoAndVideo;
    self.photoManager.configuration.singleJumpEdit = NO;
    self.photoManager.configuration.singleSelected = NO;
    self.photoManager.configuration.lookGifPhoto = YES;
    self.photoManager.configuration.lookLivePhoto = YES;
    self.photoManager.configuration.photoEditConfigur.aspectRatio = HXPhotoEditAspectRatioType_None;
    self.photoManager.configuration.photoEditConfigur.onlyCliping = NO;
}
- (void)presentMomentPublish {
    // 恢复dismiss的动画
    self.photoManager.selectPhotoFinishDismissAnimated = YES;
    self.photoManager.cameraFinishDismissAnimated = YES;
    
    WxMomentPublishViewController *vc = [[WxMomentPublishViewController alloc] init];
    vc.photoManager = self.photoManager;

    vc.modalPresentationStyle = UIModalPresentationOverFullScreen;
    vc.modalPresentationCapturesStatusBarAppearance = YES;
    [self presentViewController:vc animated:YES completion:nil];
}
#pragma mark - < HXCustomCameraViewControllerDelegate >
- (void)customCameraViewController:(HXCustomCameraViewController *)viewController didDone:(HXPhotoModel *)model {
    [self.photoManager afterListAddCameraTakePicturesModel:model];
}
- (void)customCameraViewControllerFinishDismissCompletion:(HXPhotoPreviewViewController *)previewController {
    [self presentMomentPublish];
}
#pragma mark - < HXCustomNavigationControllerDelegate >
- (void)photoNavigationViewControllerFinishDismissCompletion:(HXCustomNavigationController *)photoNavigationViewController {
    [self presentMomentPublish];
}
#pragma mark - < UITableViewDataSource >
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 10;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    WxMomentViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"WxMomentViewCellId"];
    
    return cell;
}

- (WxMomentHeaderView *)headerView {
    if (!_headerView) {
        _headerView = [WxMomentHeaderView initView];
        _headerView.photoManager = self.photoManager;
        _headerView.frame = CGRectMake(0, 0, HX_ScreenWidth, HX_ScreenWidth + 80);
    }
    return _headerView;
}
- (HXPhotoCustomNavigationBar *)customNavBar {
    if (!_customNavBar) {
        _customNavBar = [[HXPhotoCustomNavigationBar alloc] initWithFrame:CGRectMake(0, 0, HX_ScreenWidth, hxNavigationBarHeight)];
        _customNavBar.tintColor = [UIColor whiteColor];
        [_customNavBar setBackgroundImage:[UIImage hx_imageWithColor:[UIColor clearColor] havingSize:CGSizeMake(HX_ScreenWidth, hxNavigationBarHeight)] forBarMetrics:UIBarMetricsDefault];
        [_customNavBar setShadowImage:[UIImage new]];
        [_customNavBar pushNavigationItem:self.navItem animated:NO];
    }
    return _customNavBar;
}
- (UINavigationItem *)navItem {
    if (!_navItem) {
        _navItem = [[UINavigationItem alloc] init];
        _navItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"hotweibo_back_icon"] style:UIBarButtonItemStylePlain target:self action:@selector(backClick)];
        _navItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage hx_imageNamed:@"hx_camera_overturn"] style:UIBarButtonItemStylePlain target:self action:@selector(didNavItemClick)];
    }
    return _navItem;
}

- (UIView *)topView {
    if (!_topView) {
        _topView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, HX_ScreenWidth, hxNavigationBarHeight)];
        [_topView.layer addSublayer:self.topMaskLayer];
        self.topMaskLayer.frame = CGRectMake(0, 0, HX_ScreenWidth, hxNavigationBarHeight + 30);
    }
    return _topView;
}
- (CAGradientLayer *)topMaskLayer {
    if (!_topMaskLayer) {
        _topMaskLayer = [CAGradientLayer layer];
        _topMaskLayer.colors = @[
                                    (id)[[UIColor blackColor] colorWithAlphaComponent:0].CGColor,
                                    (id)[[UIColor blackColor] colorWithAlphaComponent:0.3].CGColor
                                    ];
        _topMaskLayer.startPoint = CGPointMake(0, 1);
        _topMaskLayer.endPoint = CGPointMake(0, 0);
        _topMaskLayer.locations = @[@(0.15f),@(0.9f)];
        _topMaskLayer.borderWidth  = 0.0;
    }
    return _topMaskLayer;
}
@end
