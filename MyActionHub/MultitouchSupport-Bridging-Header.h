//
//  MultitouchSupport-Bridging-Header.h
//  MyActionHub
//
//  非公開 MultitouchSupport.framework のシンボル宣言。
//  Apple は公式ヘッダを配布していないため、コミュニティ既知のシグネチャを採用。
//  詳細な理由は docs/adr/0001-multitouch-private-framework.md を参照。
//
//  Phase 4 (ジェスチャー検出) で本格的に使用。
//

#ifndef MultitouchSupport_Bridging_Header_h
#define MultitouchSupport_Bridging_Header_h

#import <CoreFoundation/CoreFoundation.h>

typedef struct {
    float x;
    float y;
} MTPoint;

typedef struct {
    MTPoint position;
    MTPoint velocity;
} MTReadout;

// 1フレーム分のタッチ情報。MultitouchSupport がコールバックで返す配列の要素。
typedef struct {
    int32_t frame;
    double timestamp;
    int32_t identifier;
    int32_t state;     // 1:starting / 2:hovering / 3:making touch / 4:touching / 5:breaking / 6:lingering / 7:leaving
    int32_t fingerId;
    int32_t handId;
    MTReadout normalized; // 0.0〜1.0 範囲
    float size;
    int32_t something;
    float angle;
    float majorAxis;
    float minorAxis;
    MTReadout absolute;
    int32_t something2;
    int32_t something3;
    float zDensity;
} MTTouch;

typedef struct __MTDevice *MTDeviceRef;

// canonical なコールバック型: 第1引数は MTDeviceRef ではなく int32_t (デバイス ID)。
// 各種リバースエンジニアリングされたヘッダで一致している形。
typedef int (*MTContactCallbackFunction)(int32_t device,
                                         MTTouch *touches,
                                         int32_t numTouches,
                                         double timestamp,
                                         int32_t frame);

extern MTDeviceRef MTDeviceCreateDefault(void);
extern CFArrayRef  MTDeviceCreateList(void);
// 戻り値は OSStatus(int)。0 が成功。
extern int         MTRegisterContactFrameCallback(MTDeviceRef device,
                                                  MTContactCallbackFunction callback);
extern int         MTUnregisterContactFrameCallback(MTDeviceRef device,
                                                    MTContactCallbackFunction callback);
extern int         MTDeviceStart(MTDeviceRef device, int unknown);
extern int         MTDeviceStop(MTDeviceRef device);
extern bool        MTDeviceIsRunning(MTDeviceRef device);

#endif /* MultitouchSupport_Bridging_Header_h */
