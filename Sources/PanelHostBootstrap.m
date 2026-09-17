#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

extern void PanelHostStart(void);

__attribute__((constructor)) static void PanelHostBootstrap(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        PanelHostStart();
    });
}
