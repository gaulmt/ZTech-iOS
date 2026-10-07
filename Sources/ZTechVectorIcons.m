#import "ZTechVectorIcons.h"

@implementation ZTechVectorIcons

+ (UIImage *)brandCrestLogoWithSize:(CGFloat)ptSize {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(ptSize, ptSize), NO, 3.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGFloat scale = ptSize / 40.0;
    CGContextScaleCTM(ctx, scale, scale);

    UIColor *goldLight = [UIColor colorWithRed:0.96 green:0.87 blue:0.60 alpha:1.0];
    UIColor *goldDeep = [UIColor colorWithRed:0.78 green:0.64 blue:0.32 alpha:1.0];
    UIColor *obsidian = [UIColor colorWithRed:0.06 green:0.08 blue:0.06 alpha:1.0];
    UIColor *emerald = [UIColor colorWithRed:0.30 green:0.88 blue:0.52 alpha:1.0];

    // 1. Outer Hexagonal Shield Bezel
    UIBezierPath *shield = [UIBezierPath bezierPath];
    [shield moveToPoint:CGPointMake(20.0, 2.5)];
    [shield addLineToPoint:CGPointMake(34.5, 8.5)];
    [shield addLineToPoint:CGPointMake(34.5, 21.5)];
    [shield addCurveToPoint:CGPointMake(20.0, 37.5)
              controlPoint1:CGPointMake(34.5, 29.5)
              controlPoint2:CGPointMake(27.5, 34.8)];
    [shield addCurveToPoint:CGPointMake(5.5, 21.5)
              controlPoint1:CGPointMake(12.5, 34.8)
              controlPoint2:CGPointMake(5.5, 29.5)];
    [shield addLineToPoint:CGPointMake(5.5, 8.5)];
    [shield closePath];

    [[goldDeep colorWithAlphaComponent:0.22] setFill];
    [shield fill];

    shield.lineWidth = 2.2;
    shield.lineJoinStyle = kCGLineJoinRound;
    [goldLight setStroke];
    [shield stroke];

    // 2. Inner Obsidian Faceted Core
    UIBezierPath *inner = [UIBezierPath bezierPath];
    [inner moveToPoint:CGPointMake(20.0, 6.2)];
    [inner addLineToPoint:CGPointMake(31.0, 10.8)];
    [inner addLineToPoint:CGPointMake(31.0, 20.8)];
    [inner addCurveToPoint:CGPointMake(20.0, 33.5)
             controlPoint1:CGPointMake(31.0, 27.0)
             controlPoint2:CGPointMake(25.5, 31.2)];
    [inner addCurveToPoint:CGPointMake(9.0, 20.8)
             controlPoint1:CGPointMake(14.5, 31.2)
             controlPoint2:CGPointMake(9.0, 27.0)];
    [inner addLineToPoint:CGPointMake(9.0, 10.8)];
    [inner closePath];
    [obsidian setFill];
    [inner fill];

    inner.lineWidth = 1.0;
    [[goldLight colorWithAlphaComponent:0.45] setStroke];
    [inner stroke];

    // 3. Custom Geometric "G" + "T" Vector Monogram
    UIBezierPath *mono = [UIBezierPath bezierPath];
    // Letter G (Left-Center)
    [mono moveToPoint:CGPointMake(19.2, 13.5)];
    [mono addLineToPoint:CGPointMake(13.8, 13.5)];
    [mono addLineToPoint:CGPointMake(12.5, 15.2)];
    [mono addLineToPoint:CGPointMake(12.5, 22.8)];
    [mono addLineToPoint:CGPointMake(14.0, 24.5)];
    [mono addLineToPoint:CGPointMake(19.2, 24.5)];
    [mono addLineToPoint:CGPointMake(19.2, 19.2)];
    [mono addLineToPoint:CGPointMake(16.2, 19.2)];

    // Letter T (Right-Center)
    [mono moveToPoint:CGPointMake(21.2, 13.5)];
    [mono addLineToPoint:CGPointMake(28.2, 13.5)];
    [mono moveToPoint:CGPointMake(24.7, 13.5)];
    [mono addLineToPoint:CGPointMake(24.7, 24.5)];

    mono.lineWidth = 2.4;
    mono.lineCapStyle = kCGLineCapRound;
    mono.lineJoinStyle = kCGLineJoinRound;
    [goldLight setStroke];
    [mono stroke];

    // 4. Bottom Emerald Status Jewel Node
    UIBezierPath *dot = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(18.2, 27.6, 3.6, 3.6)];
    [emerald setFill];
    [dot fill];

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [img imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
}

+ (UIImage *)iconWithType:(ZTechCustomIconType)type
                     size:(CGFloat)ptSize
                    color:(UIColor *)primaryColor {
    if (type == ZTechIconBrandCrest) {
        return [self brandCrestLogoWithSize:ptSize];
    }

    UIGraphicsBeginImageContextWithOptions(CGSizeMake(ptSize, ptSize), NO, 3.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGFloat scale = ptSize / 24.0;
    CGContextScaleCTM(ctx, scale, scale);

    UIColor *duotoneFill = [primaryColor colorWithAlphaComponent:0.18];
    UIColor *softStroke = [primaryColor colorWithAlphaComponent:0.45];

    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextSetLineJoin(ctx, kCGLineJoinRound);

    switch (type) {
        case ZTechIconTabSpoof:
        case ZTechIconChipCpu: {
            // Duotone Silicon Die Core
            UIBezierPath *die = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(5.5, 5.5, 13.0, 13.0) cornerRadius:3.0];
            [duotoneFill setFill];
            [die fill];
            die.lineWidth = 1.9;
            [primaryColor setStroke];
            [die stroke];

            // Inner Bionic Core + Lightning Pulse
            UIBezierPath *inner = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(8.8, 8.8, 6.4, 6.4) cornerRadius:1.4];
            [[primaryColor colorWithAlphaComponent:0.28] setFill];
            [inner fill];
            inner.lineWidth = 1.4;
            [inner stroke];

            // 12 Contact Pins (3 per side)
            UIBezierPath *pins = [UIBezierPath bezierPath];
            CGFloat pos[3] = {8.5, 12.0, 15.5};
            for (int i = 0; i < 3; i++) {
                CGFloat p = pos[i];
                // Top
                [pins moveToPoint:CGPointMake(p, 2.5)]; [pins addLineToPoint:CGPointMake(p, 5.5)];
                // Bottom
                [pins moveToPoint:CGPointMake(p, 18.5)]; [pins addLineToPoint:CGPointMake(p, 21.5)];
                // Left
                [pins moveToPoint:CGPointMake(2.5, p)]; [pins addLineToPoint:CGPointMake(5.5, p)];
                // Right
                [pins moveToPoint:CGPointMake(18.5, p)]; [pins addLineToPoint:CGPointMake(21.5, p)];
            }
            pins.lineWidth = 1.75;
            [primaryColor setStroke];
            [pins stroke];
            break;
        }

        case ZTechIconTabVault: {
            // Luxury Multi-Layer Vault Safe
            UIBezierPath *outer = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(3.0, 3.5, 18.0, 17.0) cornerRadius:3.5];
            [duotoneFill setFill];
            [outer fill];
            outer.lineWidth = 1.9;
            [primaryColor setStroke];
            [outer stroke];

            // Vault Door Inner Frame
            UIBezierPath *frame = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(6.0, 6.5, 12.0, 11.0) cornerRadius:2.0];
            frame.lineWidth = 1.3;
            [softStroke setStroke];
            [frame stroke];

            // Combination Dial Wheel + Spokes
            UIBezierPath *dial = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(9.5, 9.5, 5.0, 5.0)];
            [primaryColor setStroke];
            dial.lineWidth = 1.8;
            [dial stroke];

            UIBezierPath *spokes = [UIBezierPath bezierPath];
            [spokes moveToPoint:CGPointMake(12.0, 8.2)]; [spokes addLineToPoint:CGPointMake(12.0, 15.8)];
            [spokes moveToPoint:CGPointMake(8.2, 12.0)]; [spokes addLineToPoint:CGPointMake(15.8, 12.0)];
            spokes.lineWidth = 1.5;
            [spokes stroke];
            break;
        }

        case ZTechIconTabLicense:
        case ZTechIconKeyVip: {
            // Hexagonal Cryptographic Key
            UIBezierPath *ring = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(3.0, 7.5, 9.0, 9.0)];
            [duotoneFill setFill];
            [ring fill];
            ring.lineWidth = 1.95;
            [primaryColor setStroke];
            [ring stroke];

            UIBezierPath *hole = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(6.2, 10.7, 2.6, 2.6)];
            [primaryColor setFill];
            [hole fill];

            UIBezierPath *shaft = [UIBezierPath bezierPath];
            [shaft moveToPoint:CGPointMake(12.0, 12.0)];
            [shaft addLineToPoint:CGPointMake(21.0, 12.0)];
            [shaft moveToPoint:CGPointMake(16.5, 12.0)];
            [shaft addLineToPoint:CGPointMake(16.5, 15.5)];
            [shaft moveToPoint:CGPointMake(19.8, 12.0)];
            [shaft addLineToPoint:CGPointMake(19.8, 16.2)];
            shaft.lineWidth = 2.0;
            shaft.lineCapStyle = kCGLineCapRound;
            [primaryColor setStroke];
            [shaft stroke];
            break;
        }

        case ZTechIconDevicePhone: {
            // Bezel-less iPhone 16 Pro Max with Dynamic Island
            UIBezierPath *body = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(6.0, 2.2, 12.0, 19.6) cornerRadius:3.0];
            [duotoneFill setFill];
            [body fill];
            body.lineWidth = 1.9;
            [primaryColor setStroke];
            [body stroke];

            // Dynamic Island Pill
            UIBezierPath *island = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(9.8, 4.6, 4.4, 1.5) cornerRadius:0.75];
            [primaryColor setFill];
            [island fill];

            // Home Indicator Bar
            UIBezierPath *bar = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(9.5, 19.0, 5.0, 1.1) cornerRadius:0.55];
            [primaryColor setFill];
            [bar fill];
            break;
        }

        case ZTechIconDisplayScreen: {
            // Viewport Frame with Corner Calibration Brackets
            UIBezierPath *scr = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(3.0, 4.0, 18.0, 16.0) cornerRadius:3.0];
            [duotoneFill setFill];
            [scr fill];
            scr.lineWidth = 1.85;
            [primaryColor setStroke];
            [scr stroke];

            UIBezierPath *corners = [UIBezierPath bezierPath];
            // Top-Left bracket
            [corners moveToPoint:CGPointMake(6.5, 9.5)];
            [corners addLineToPoint:CGPointMake(6.5, 7.2)];
            [corners addLineToPoint:CGPointMake(9.2, 7.2)];
            // Bottom-Right bracket
            [corners moveToPoint:CGPointMake(17.5, 14.5)];
            [corners addLineToPoint:CGPointMake(17.5, 16.8)];
            [corners addLineToPoint:CGPointMake(14.8, 16.8)];
            // Diagonal calibration line
            [corners moveToPoint:CGPointMake(9.0, 15.0)];
            [corners addLineToPoint:CGPointMake(15.0, 9.0)];
            corners.lineWidth = 1.65;
            [primaryColor setStroke];
            [corners stroke];
            break;
        }

        case ZTechIconSignalRadar: {
            // Concentric Cellular / WiFi Radar Waves
            UIBezierPath *dot = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(10.4, 16.8, 3.2, 3.2)];
            [primaryColor setFill];
            [dot fill];

            UIBezierPath *w1 = [UIBezierPath bezierPathWithArcCenter:CGPointMake(12.0, 18.4)
                                                              radius:4.8
                                                          startAngle:(CGFloat)(-M_PI * 0.78)
                                                            endAngle:(CGFloat)(-M_PI * 0.22)
                                                           clockwise:YES];
            UIBezierPath *w2 = [UIBezierPath bezierPathWithArcCenter:CGPointMake(12.0, 18.4)
                                                              radius:8.6
                                                          startAngle:(CGFloat)(-M_PI * 0.80)
                                                            endAngle:(CGFloat)(-M_PI * 0.20)
                                                           clockwise:YES];
            UIBezierPath *w3 = [UIBezierPath bezierPathWithArcCenter:CGPointMake(12.0, 18.4)
                                                              radius:12.4
                                                          startAngle:(CGFloat)(-M_PI * 0.82)
                                                            endAngle:(CGFloat)(-M_PI * 0.18)
                                                           clockwise:YES];
            w1.lineWidth = 1.9;
            w2.lineWidth = 1.9;
            w3.lineWidth = 1.9;
            [primaryColor setStroke];
            [w1 stroke];
            [w2 stroke];
            [w3 stroke];
            break;
        }

        case ZTechIconBatteryBolt: {
            // Armored Battery Cell + Lightning Bolt
            UIBezierPath *cell = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(2.5, 6.5, 16.5, 11.0) cornerRadius:2.6];
            [duotoneFill setFill];
            [cell fill];
            cell.lineWidth = 1.9;
            [primaryColor setStroke];
            [cell stroke];

            UIBezierPath *cap = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(20.2, 9.6, 1.8, 4.8) cornerRadius:0.9];
            [primaryColor setFill];
            [cap fill];

            UIBezierPath *bolt = [UIBezierPath bezierPath];
            [bolt moveToPoint:CGPointMake(11.6, 8.2)];
            [bolt addLineToPoint:CGPointMake(8.8, 12.2)];
            [bolt addLineToPoint:CGPointMake(11.4, 12.2)];
            [bolt addLineToPoint:CGPointMake(10.0, 15.8)];
            [bolt addLineToPoint:CGPointMake(13.2, 11.6)];
            [bolt addLineToPoint:CGPointMake(10.6, 11.6)];
            [bolt closePath];
            [primaryColor setFill];
            [bolt fill];
            break;
        }

        case ZTechIconRefreshMorph: {
            // Dual-Arc Orbital Sync Arrows + Center Core
            UIBezierPath *center = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(9.5, 9.5, 5.0, 5.0)];
            [duotoneFill setFill];
            [center fill];
            center.lineWidth = 1.5;
            [primaryColor setStroke];
            [center stroke];

            UIBezierPath *arc1 = [UIBezierPath bezierPathWithArcCenter:CGPointMake(12.0, 12.0)
                                                                radius:8.2
                                                            startAngle:(CGFloat)(-M_PI * 0.85)
                                                              endAngle:(CGFloat)(-M_PI * 0.12)
                                                             clockwise:YES];
            arc1.lineWidth = 2.0;
            [arc1 stroke];

            UIBezierPath *head1 = [UIBezierPath bezierPath];
            [head1 moveToPoint:CGPointMake(16.2, 4.2)];
            [head1 addLineToPoint:CGPointMake(19.8, 8.6)];
            [head1 addLineToPoint:CGPointMake(14.8, 9.0)];
            head1.lineWidth = 2.0;
            [head1 stroke];

            UIBezierPath *arc2 = [UIBezierPath bezierPathWithArcCenter:CGPointMake(12.0, 12.0)
                                                                radius:8.2
                                                            startAngle:(CGFloat)(M_PI * 0.15)
                                                              endAngle:(CGFloat)(M_PI * 0.88)
                                                             clockwise:YES];
            arc2.lineWidth = 2.0;
            [arc2 stroke];

            UIBezierPath *head2 = [UIBezierPath bezierPath];
            [head2 moveToPoint:CGPointMake(7.8, 19.8)];
            [head2 addLineToPoint:CGPointMake(4.2, 15.4)];
            [head2 addLineToPoint:CGPointMake(9.2, 15.0)];
            head2.lineWidth = 2.0;
            [head2 stroke];
            break;
        }

        case ZTechIconCleanWipe: {
            // Cyber Purge Vortex + Sparkle Stars
            UIBezierPath *shield = [UIBezierPath bezierPath];
            [shield moveToPoint:CGPointMake(12.0, 3.0)];
            [shield addLineToPoint:CGPointMake(19.5, 6.2)];
            [shield addLineToPoint:CGPointMake(19.5, 12.5)];
            [shield addCurveToPoint:CGPointMake(12.0, 21.0)
                      controlPoint1:CGPointMake(19.5, 16.8)
                      controlPoint2:CGPointMake(16.0, 19.5)];
            [shield addCurveToPoint:CGPointMake(4.5, 12.5)
                      controlPoint1:CGPointMake(8.0, 19.5)
                      controlPoint2:CGPointMake(4.5, 16.8)];
            [shield addLineToPoint:CGPointMake(4.5, 6.2)];
            [shield closePath];
            [duotoneFill setFill];
            [shield fill];
            shield.lineWidth = 1.9;
            [primaryColor setStroke];
            [shield stroke];

            // Sparkle Cross inside
            UIBezierPath *spark = [UIBezierPath bezierPath];
            [spark moveToPoint:CGPointMake(12.0, 8.0)]; [spark addLineToPoint:CGPointMake(12.0, 15.6)];
            [spark moveToPoint:CGPointMake(8.2, 11.8)]; [spark addLineToPoint:CGPointMake(15.8, 11.8)];
            spark.lineWidth = 2.0;
            [primaryColor setStroke];
            [spark stroke];
            break;
        }

        case ZTechIconLocationPin: {
            // Precision GPS Pin + Target Radar
            UIBezierPath *pin = [UIBezierPath bezierPath];
            [pin moveToPoint:CGPointMake(12.0, 21.2)];
            [pin addCurveToPoint:CGPointMake(5.2, 10.0)
                   controlPoint1:CGPointMake(8.0, 17.2)
                   controlPoint2:CGPointMake(5.2, 13.6)];
            [pin addArcWithCenter:CGPointMake(12.0, 10.0)
                           radius:6.8
                       startAngle:(CGFloat)M_PI
                         endAngle:0.0
                        clockwise:YES];
            [pin addCurveToPoint:CGPointMake(12.0, 21.2)
                   controlPoint1:CGPointMake(18.8, 13.6)
                   controlPoint2:CGPointMake(16.0, 17.2)];
            [pin closePath];

            [duotoneFill setFill];
            [pin fill];
            pin.lineWidth = 1.9;
            [primaryColor setStroke];
            [pin stroke];

            UIBezierPath *core = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(9.6, 7.6, 4.8, 4.8)];
            [primaryColor setFill];
            [core fill];
            break;
        }

        case ZTechIconRocketLaunch: {
            // Fast Launch Portal Arrow
            UIBezierPath *portal = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(3.0, 3.0, 18.0, 18.0) cornerRadius:5.0];
            [duotoneFill setFill];
            [portal fill];
            portal.lineWidth = 1.85;
            [primaryColor setStroke];
            [portal stroke];

            UIBezierPath *play = [UIBezierPath bezierPath];
            [play moveToPoint:CGPointMake(9.5, 7.6)];
            [play addLineToPoint:CGPointMake(16.5, 12.0)];
            [play addLineToPoint:CGPointMake(9.5, 16.4)];
            [play closePath];
            [primaryColor setFill];
            [play fill];
            play.lineWidth = 1.4;
            [primaryColor setStroke];
            [play stroke];
            break;
        }

        case ZTechIconVaultSave: {
            // Vault Tray + Downward Injection Arrow
            UIBezierPath *tray = [UIBezierPath bezierPath];
            [tray moveToPoint:CGPointMake(3.5, 14.0)];
            [tray addLineToPoint:CGPointMake(3.5, 18.5)];
            [tray addQuadCurveToPoint:CGPointMake(6.0, 20.5) controlPoint:CGPointMake(3.5, 20.5)];
            [tray addLineToPoint:CGPointMake(18.0, 20.5)];
            [tray addQuadCurveToPoint:CGPointMake(20.5, 18.5) controlPoint:CGPointMake(20.5, 20.5)];
            [tray addLineToPoint:CGPointMake(20.5, 14.0)];
            tray.lineWidth = 2.0;
            [primaryColor setStroke];
            [tray stroke];

            UIBezierPath *baseFill = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(4.5, 15.5, 15.0, 4.0) cornerRadius:1.5];
            [duotoneFill setFill];
            [baseFill fill];

            UIBezierPath *arr = [UIBezierPath bezierPath];
            [arr moveToPoint:CGPointMake(12.0, 3.2)];
            [arr addLineToPoint:CGPointMake(12.0, 14.2)];
            [arr moveToPoint:CGPointMake(8.0, 10.4)];
            [arr addLineToPoint:CGPointMake(12.0, 14.4)];
            [arr addLineToPoint:CGPointMake(16.0, 10.4)];
            arr.lineWidth = 2.1;
            [primaryColor setStroke];
            [arr stroke];
            break;
        }

        case ZTechIconProxyNodes: {
            // 3-Node Encrypted Proxy Mesh (Top Shield Node + 2 Bottom Endpoint Nodes)
            UIBezierPath *links = [UIBezierPath bezierPath];
            [links moveToPoint:CGPointMake(12.0, 8.5)];
            [links addLineToPoint:CGPointMake(6.2, 16.5)];
            [links moveToPoint:CGPointMake(12.0, 8.5)];
            [links addLineToPoint:CGPointMake(17.8, 16.5)];
            [links moveToPoint:CGPointMake(6.2, 17.5)];
            [links addLineToPoint:CGPointMake(17.8, 17.5)];
            links.lineWidth = 1.7;
            [softStroke setStroke];
            [links stroke];

            UIBezierPath *nTop = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(8.8, 3.0, 6.4, 6.4)];
            UIBezierPath *nLeft = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(3.0, 14.5, 5.6, 5.6)];
            UIBezierPath *nRight = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(15.4, 14.5, 5.6, 5.6)];

            [duotoneFill setFill];
            [nTop fill]; [nLeft fill]; [nRight fill];

            nTop.lineWidth = 1.9; nLeft.lineWidth = 1.9; nRight.lineWidth = 1.9;
            [primaryColor setStroke];
            [nTop stroke]; [nLeft stroke]; [nRight stroke];
            break;
        }

        case ZTechIconSlidersTune: {
            // 3-Track Precision Equalizer Sliders
            UIBezierPath *tracks = [UIBezierPath bezierPath];
            [tracks moveToPoint:CGPointMake(3.5, 6.5)]; [tracks addLineToPoint:CGPointMake(20.5, 6.5)];
            [tracks moveToPoint:CGPointMake(3.5, 12.0)]; [tracks addLineToPoint:CGPointMake(20.5, 12.0)];
            [tracks moveToPoint:CGPointMake(3.5, 17.5)]; [tracks addLineToPoint:CGPointMake(20.5, 17.5)];
            tracks.lineWidth = 1.8;
            [softStroke setStroke];
            [tracks stroke];

            UIBezierPath *k1 = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(7.0, 4.2, 4.6, 4.6)];
            UIBezierPath *k2 = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(13.0, 9.7, 4.6, 4.6)];
            UIBezierPath *k3 = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(8.5, 15.2, 4.6, 4.6)];
            [primaryColor setFill];
            [k1 fill]; [k2 fill]; [k3 fill];
            break;
        }

        case ZTechIconTrashDelete: {
            // Geometric Shredder Bin
            UIBezierPath *bin = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(5.5, 7.0, 13.0, 13.5) cornerRadius:2.2];
            [duotoneFill setFill];
            [bin fill];
            bin.lineWidth = 1.85;
            [primaryColor setStroke];
            [bin stroke];

            UIBezierPath *lid = [UIBezierPath bezierPath];
            [lid moveToPoint:CGPointMake(3.5, 7.0)]; [lid addLineToPoint:CGPointMake(20.5, 7.0)];
            [lid moveToPoint:CGPointMake(9.2, 7.0)]; [lid addLineToPoint:CGPointMake(9.2, 4.2)];
            [lid addLineToPoint:CGPointMake(14.8, 4.2)]; [lid addLineToPoint:CGPointMake(14.8, 7.0)];
            [lid moveToPoint:CGPointMake(10.0, 10.5)]; [lid addLineToPoint:CGPointMake(10.0, 16.8)];
            [lid moveToPoint:CGPointMake(14.0, 10.5)]; [lid addLineToPoint:CGPointMake(14.0, 16.8)];
            lid.lineWidth = 1.85;
            [primaryColor setStroke];
            [lid stroke];
            break;
        }

        case ZTechIconCopyClone: {
            // Overlapping Dual Document Cards
            UIBezierPath *back = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(4.0, 3.5, 11.5, 13.0) cornerRadius:2.4];
            back.lineWidth = 1.75;
            [softStroke setStroke];
            [back stroke];

            UIBezierPath *front = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(8.5, 7.5, 11.5, 13.0) cornerRadius:2.4];
            [duotoneFill setFill];
            [front fill];
            front.lineWidth = 1.9;
            [primaryColor setStroke];
            [front stroke];

            UIBezierPath *lines = [UIBezierPath bezierPath];
            [lines moveToPoint:CGPointMake(11.2, 12.0)]; [lines addLineToPoint:CGPointMake(17.2, 12.0)];
            [lines moveToPoint:CGPointMake(11.2, 15.5)]; [lines addLineToPoint:CGPointMake(15.5, 15.5)];
            lines.lineWidth = 1.7;
            [primaryColor setStroke];
            [lines stroke];
            break;
        }

        case ZTechIconClipboardPaste: {
            // Clipboard with Metallic Top Clamp
            UIBezierPath *board = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(5.0, 5.0, 14.0, 16.0) cornerRadius:2.6];
            [duotoneFill setFill];
            [board fill];
            board.lineWidth = 1.85;
            [primaryColor setStroke];
            [board stroke];

            UIBezierPath *clip = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(8.8, 3.0, 6.4, 3.6) cornerRadius:1.4];
            [primaryColor setFill];
            [clip fill];

            UIBezierPath *chk = [UIBezierPath bezierPath];
            [chk moveToPoint:CGPointMake(8.8, 13.2)];
            [chk addLineToPoint:CGPointMake(11.2, 15.6)];
            [chk addLineToPoint:CGPointMake(15.6, 10.8)];
            chk.lineWidth = 2.0;
            [primaryColor setStroke];
            [chk stroke];
            break;
        }

        case ZTechIconShieldCheck: {
            // Luxury Faceted Security Shield + Checkmark
            UIBezierPath *shield = [UIBezierPath bezierPath];
            [shield moveToPoint:CGPointMake(12.0, 2.6)];
            [shield addLineToPoint:CGPointMake(19.8, 6.0)];
            [shield addLineToPoint:CGPointMake(19.8, 12.4)];
            [shield addCurveToPoint:CGPointMake(12.0, 21.4)
                      controlPoint1:CGPointMake(19.8, 17.0)
                      controlPoint2:CGPointMake(16.2, 19.8)];
            [shield addCurveToPoint:CGPointMake(4.2, 12.4)
                      controlPoint1:CGPointMake(7.8, 19.8)
                      controlPoint2:CGPointMake(4.2, 17.0)];
            [shield addLineToPoint:CGPointMake(4.2, 6.0)];
            [shield closePath];

            [duotoneFill setFill];
            [shield fill];
            shield.lineWidth = 1.95;
            [primaryColor setStroke];
            [shield stroke];

            UIBezierPath *chk = [UIBezierPath bezierPath];
            [chk moveToPoint:CGPointMake(8.5, 12.2)];
            [chk addLineToPoint:CGPointMake(11.0, 14.8)];
            [chk addLineToPoint:CGPointMake(15.8, 9.6)];
            chk.lineWidth = 2.2;
            [primaryColor setStroke];
            [chk stroke];
            break;
        }

        case ZTechIconShieldLock: {
            // Armored Padlock with Keyhole
            UIBezierPath *body = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(5.0, 10.5, 14.0, 10.5) cornerRadius:2.8];
            [duotoneFill setFill];
            [body fill];
            body.lineWidth = 1.9;
            [primaryColor setStroke];
            [body stroke];

            UIBezierPath *shackle = [UIBezierPath bezierPath];
            [shackle moveToPoint:CGPointMake(8.0, 10.5)];
            [shackle addLineToPoint:CGPointMake(8.0, 7.2)];
            [shackle addArcWithCenter:CGPointMake(12.0, 7.2) radius:4.0 startAngle:(CGFloat)M_PI endAngle:0.0 clockwise:YES];
            [shackle addLineToPoint:CGPointMake(16.0, 10.5)];
            shackle.lineWidth = 1.95;
            [primaryColor setStroke];
            [shackle stroke];

            UIBezierPath *dot = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(10.6, 14.2, 2.8, 2.8)];
            [primaryColor setFill];
            [dot fill];
            break;
        }

        case ZTechIconKeypadGrid: {
            // Tactile Keyboard / Matrix Grid
            UIBezierPath *frame = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(2.5, 5.0, 19.0, 14.0) cornerRadius:3.0];
            [duotoneFill setFill];
            [frame fill];
            frame.lineWidth = 1.85;
            [primaryColor setStroke];
            [frame stroke];

            CGFloat xs[4] = {6.2, 10.0, 14.0, 17.8};
            for (int i = 0; i < 4; i++) {
                UIBezierPath *d1 = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(xs[i] - 1.0, 8.2, 2.0, 2.0)];
                UIBezierPath *d2 = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(xs[i] - 1.0, 11.6, 2.0, 2.0)];
                [primaryColor setFill];
                [d1 fill]; [d2 fill];
            }
            UIBezierPath *space = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(7.5, 15.2, 9.0, 1.6) cornerRadius:0.8];
            [primaryColor setFill];
            [space fill];
            break;
        }

        case ZTechIconCloudSync: {
            // Cloud Silhouette + Upstash Sync Node
            UIBezierPath *cloud = [UIBezierPath bezierPath];
            [cloud moveToPoint:CGPointMake(6.5, 18.5)];
            [cloud addLineToPoint:CGPointMake(17.5, 18.5)];
            [cloud addArcWithCenter:CGPointMake(17.5, 14.8) radius:3.7 startAngle:(CGFloat)M_PI_2 endAngle:(CGFloat)(-M_PI_2) clockwise: NO];
            [cloud addArcWithCenter:CGPointMake(12.2, 10.5) radius:5.0 startAngle:0.0 endAngle:(CGFloat)(-M_PI) clockwise:NO];
            [cloud addArcWithCenter:CGPointMake(6.5, 14.5) radius:4.0 startAngle:(CGFloat)(-M_PI_2) endAngle:(CGFloat)M_PI_2 clockwise:NO];
            [cloud closePath];

            [duotoneFill setFill];
            [cloud fill];
            cloud.lineWidth = 1.9;
            [primaryColor setStroke];
            [cloud stroke];

            UIBezierPath *sync = [UIBezierPath bezierPath];
            [sync moveToPoint:CGPointMake(12.0, 16.2)];
            [sync addLineToPoint:CGPointMake(12.0, 10.8)];
            [sync moveToPoint:CGPointMake(9.6, 13.0)];
            [sync addLineToPoint:CGPointMake(12.0, 10.6)];
            [sync addLineToPoint:CGPointMake(14.4, 13.0)];
            sync.lineWidth = 1.95;
            [primaryColor setStroke];
            [sync stroke];
            break;
        }

        case ZTechIconCrownTier: {
            // Royal 3-Peak Crown with Jewels
            UIBezierPath *crown = [UIBezierPath bezierPath];
            [crown moveToPoint:CGPointMake(4.0, 18.0)];
            [crown addLineToPoint:CGPointMake(3.0, 8.5)];
            [crown addLineToPoint:CGPointMake(8.2, 12.5)];
            [crown addLineToPoint:CGPointMake(12.0, 5.5)];
            [crown addLineToPoint:CGPointMake(15.8, 12.5)];
            [crown addLineToPoint:CGPointMake(21.0, 8.5)];
            [crown addLineToPoint:CGPointMake(20.0, 18.0)];
            [crown closePath];

            [duotoneFill setFill];
            [crown fill];
            crown.lineWidth = 1.9;
            [primaryColor setStroke];
            [crown stroke];
            break;
        }
    }

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [img imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
}

@end
