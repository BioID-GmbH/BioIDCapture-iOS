//
//  ResultViewController.m
//  BioIDCapture
//
//  Copyright © 2024 BioID. All rights reserved.
//

#import "ResultViewController.h"

@implementation ResultViewController

// Called after the controller`s view is loaded into memory.
- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Set backgroud white
    self.view.backgroundColor = [UIColor whiteColor];
    
    // Create WebViewer object
    WKWebView *webView = [[WKWebView alloc] initWithFrame:self.view.bounds];
    webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:webView];
    
    // Create a html string with the response of BWS
    NSString *htmlString = [NSString stringWithFormat:@"<html><head><meta name='viewport' content='width-device-width, initial-scale=1.0'></head><body><h1>Result</h1><pre style='font-size: 16px; font-family: monospace;white-space: pre-wrap;'>%@</pre></body></html>", self.jsonString];
    
    // Set html string to WebViewer
    [webView loadHTMLString:htmlString baseURL:nil];
    
    if (@available(iOS 13.0, *)) {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose
                                                                                               target:self
                                                                                               action:@selector(closeButtonTapped)];
    } else {
        // Fallback on earlier versions
    };
}

// Close ResultViewController
- (void)closeButtonTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
