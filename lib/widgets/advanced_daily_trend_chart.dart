import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../models/foreign_investor_data.dart';
import '../providers/foreign_investor_provider.dart';
import 'chart_holdings_fixer.dart';

class AdvancedDailyTrendChart extends StatefulWidget {
  final List<DailyForeignSummary> summaryData;
  final String selectedMarket;
  final VoidCallback? onRequestMoreData; // 더 많은 데이터 요청 콜백
  final String? title; // 차트 제목
  final ChartDataType? chartDataType; // 강제로 설정할 차트 데이터 타입
  final bool autoLoadActualData; // 자동으로 실제 보유액 데이터 로드 여부

  const AdvancedDailyTrendChart({
    super.key,
    required this.summaryData,
    required this.selectedMarket,
    this.onRequestMoreData,
    this.title,
    this.chartDataType,
    this.autoLoadActualData = false,
  });

  @override
  State<AdvancedDailyTrendChart> createState() => _AdvancedDailyTrendChartState();
}

class _AdvancedDailyTrendChartState extends State<AdvancedDailyTrendChart>
    with TickerProviderStateMixin {
  
  // 차트 상태 - static으로 전역 보존
  static double _globalScale = 1.0;
  static double _globalPanX = 0.0;
  static bool _globalUserHasInteracted = false;
  static bool _globalIsInitialViewSet = false;
  static bool _globalViewportLocked = false; // 뷰포트 완전 잠금
  
  // 인스턴스 변수들 (전역 상태에서 복사)
  double _scale = 1.0;
  double _panX = 0.0;
  double _lastPanX = 0.0;
  bool _isInitialViewSet = false;
  bool _userHasInteracted = false;
  
  // 툴팁 상태
  Offset? _tooltipPosition;
  DailyForeignSummary? _selectedData;
  bool _showTooltip = false;
  
  // 애니메이션 컨트롤러
  late AnimationController _animationController;
  late AnimationController _tooltipController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _tooltipAnimation;
  
  // 차트 옵션
  bool _showKospiData = true;
  bool _showKosdaqData = true;
  final bool _showCombinedData = true;
  ChartViewType _viewType = ChartViewType.combined;
  ChartDataType _dataType = ChartDataType.cumulative; // 기본값을 누적 순매수로 설정 (빠른 로딩)
  bool _isLoadingActualData = false; // 실제 보유액 데이터 로딩 상태

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    
    // 차트 데이터 타입 강제 설정 (외부에서 지정된 경우)
    if (widget.chartDataType != null) {
      _dataType = widget.chartDataType!;
      print('🎯 차트 데이터 타입 강제 설정: $_dataType');
    }
    
    // 전역 상태에서 복원 (강제 설정이 없는 경우에만)
    if (widget.chartDataType == null) {
      _scale = _globalScale;
      _panX = _globalPanX;
      _userHasInteracted = _globalUserHasInteracted;
      _isInitialViewSet = _globalIsInitialViewSet;
    }
    
    print('🚀 AdvancedDailyTrendChart initState');
    print('   - title: ${widget.title}');
    print('   - chartDataType: ${widget.chartDataType}');
    print('   - autoLoadActualData: ${widget.autoLoadActualData}');
    print('   - _dataType: $_dataType');
    
    // 자동으로 실제 보유액 데이터 로드
    if (widget.autoLoadActualData && _dataType == ChartDataType.actual) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadActualDataAutomatically();
      });
    }
    
    // 🚨 긴급 수정: 무조건 보유액 데이터 로드 (차트가 0원으로 표시되는 문제 해결)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('🚨 긴급 보유액 데이터 강제 로드 시작 (PostFrameCallback)');
      _loadActualDataAutomatically();
    });
    
    // 🚨🚨 더 강력한 수정: 2초 후에도 다시 시도
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        print('🚨🚨 2초 후 보유액 데이터 재시도');
        _loadActualDataAutomatically();
      }
    });
    
    // 🚨🚨🚨 가장 강력한 수정: 5초 후에도 다시 시도 (DB 저장 완료 후)
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        print('🚨🚨🚨 5초 후 보유액 데이터 최종 재시도');
        _loadActualDataAutomatically();
      }
    });
  }

  @override
  void didUpdateWidget(AdvancedDailyTrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    print('🔄 AdvancedDailyTrendChart didUpdateWidget 호출');
    print('   - 이전 데이터 개수: ${oldWidget.summaryData.length}');
    print('   - 현재 데이터 개수: ${widget.summaryData.length}');
    print('   - 사용자 조작 여부: $_userHasInteracted');
    print('   - 전역 사용자 조작 여부: $_globalUserHasInteracted');
    print('   - 초기 뷰 설정 여부: $_isInitialViewSet');
    print('   - 전역 초기 뷰 설정 여부: $_globalIsInitialViewSet');
    
    // 🚨 DB 저장 완료 후 즉시 차트 데이터 업데이트 시도
    print('🚨 didUpdateWidget에서 즉시 ChartHoldingsFixer 실행');
    _executeChartHoldingsFixerImmediately();
    
    // 데이터 개수가 변경된 경우에만 처리
    if (oldWidget.summaryData.length != widget.summaryData.length) {
      // 사용자가 한 번이라도 조작했거나 초기 뷰가 이미 설정되었다면 뷰포트 변경 차단
      final hasUserInteraction = _userHasInteracted || _globalUserHasInteracted;
      final isViewAlreadySet = _isInitialViewSet || _globalIsInitialViewSet;
      
      if (hasUserInteraction || isViewAlreadySet) {
        print('   🔒 뷰포트 변경 차단 - 사용자 조작 이력 또는 초기 뷰 설정 완료');
        print('      - hasUserInteraction: $hasUserInteraction');
        print('      - isViewAlreadySet: $isViewAlreadySet');
        
        // 상태를 명확히 설정하여 추가 초기화 방지
        _isInitialViewSet = true;
        _globalIsInitialViewSet = true;
        _saveStateToGlobal();
      } else {
        print('   🔄 최초 데이터 로드 - 초기 뷰포트 설정 허용');
        // 이 경우에만 초기 뷰포트 재설정 허용
        _isInitialViewSet = false;
      }
    }
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _tooltipController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _tooltipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _tooltipController, curve: Curves.elasticOut),
    );
    
    _animationController.forward();
  }

  // 상태를 전역에 저장하는 헬퍼 함수
  void _saveStateToGlobal() {
    _globalScale = _scale;
    _globalPanX = _panX;
    _globalUserHasInteracted = _userHasInteracted;
    _globalIsInitialViewSet = _isInitialViewSet;
    if (_userHasInteracted) {
      _globalViewportLocked = true; // 사용자 조작 시 완전 잠금
      print('🔒 뷰포트 완전 잠금 활성화');
    }
  }

  /// 자동으로 실제 보유액 데이터 로드
  Future<void> _loadActualDataAutomatically() async {
    print('🤖 _loadActualDataAutomatically 함수 진입');
    print('   _isLoadingActualData: $_isLoadingActualData');
    print('   mounted: $mounted');
    
    if (_isLoadingActualData) {
      print('🤖 이미 로딩 중이므로 중단');
      return;
    }
    
    print('🤖 자동 실제 보유액 데이터 로드 시작');
    _isLoadingActualData = true;
    
    try {
      final provider = Provider.of<ForeignInvestorProvider>(context, listen: false);
      print('🤖 Provider 가져옴: ${provider.runtimeType}');
      
      print('🤖 loadActualHoldingsData() 호출 시작');
      await provider.loadActualHoldingsData();
      print('🤖 loadActualHoldingsData() 호출 완료');
      
      // 🔧 ChartHoldingsFixer로 차트 데이터 강제 수정
      print('🔧 ChartHoldingsFixer로 차트 데이터 수정 시작');
      final wasFixed = await ChartHoldingsFixer.fixActualHoldingsValues(widget.summaryData);
      print('🔧 ChartHoldingsFixer 수정 결과: $wasFixed');
      
      // 수정이 성공했으면 차트 새로고침
      if (wasFixed && mounted) {
        print('🔄 차트 새로고침 실행');
        setState(() {
          // 강제로 다시 그리기
        });
      }
      
      print('🤖 자동 실제 보유액 데이터 로드 완료');
    } catch (e) {
      print('🤖 자동 실제 보유액 데이터 로드 실패: $e');
      print('🤖 에러 스택: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingActualData = false;
        });
        print('🤖 _isLoadingActualData = false 설정 완료');
      } else {
        print('🤖 위젯이 unmounted 상태');
      }
    }
  }
  
  /// DB 저장 완료 후 즉시 ChartHoldingsFixer 실행
  Future<void> _executeChartHoldingsFixerImmediately() async {
    print('🚨 _executeChartHoldingsFixerImmediately 함수 진입');
    print('   mounted: $mounted');
    print('   summaryData.length: ${widget.summaryData.length}');
    
    if (!mounted || widget.summaryData.isEmpty) {
      print('🚨 조건 불만족 - 실행 중단');
      return;
    }
    
    try {
      print('🚨 즉시 ChartHoldingsFixer 실행 시작');
      final wasFixed = await ChartHoldingsFixer.fixActualHoldingsValues(widget.summaryData);
      print('🚨 즉시 ChartHoldingsFixer 수정 결과: $wasFixed');
      
      if (wasFixed && mounted) {
        print('🚨 즉시 수정 성공 - setState() 호출');
        setState(() {
          // 강제로 차트 새로고침
        });
      }
    } catch (e) {
      print('🚨 즉시 ChartHoldingsFixer 실행 실패: $e');
    }
  }

  @override
  void dispose() {
    // 위젯 해제 시 상태 저장
    _saveStateToGlobal();
    _animationController.dispose();
    _tooltipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.summaryData.isEmpty) {
      return _buildEmptyState();
    }
    
    // 뷰포트가 잠겨있으면 무조건 차단
    if (_globalViewportLocked) {
      print('🔒 뷰포트 잠금 상태 - 모든 초기화 차단');
      return Card(
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.grey.shade50,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _buildLegendAndControls(),
                const SizedBox(height: 20),
                Container(
                  height: 350,
                  width: double.infinity,
                  clipBehavior: Clip.hardEdge,
                  decoration: const BoxDecoration(),
                  child: _buildAdvancedChart(),
                ),
                const SizedBox(height: 16),
                _buildChartInfo(),
              ],
            ),
          ),
        ),
      );
    }
    
    // 뷰포트 설정 조건을 더 엄격하게 체크
    final hasAnyUserInteraction = _userHasInteracted || _globalUserHasInteracted;
    final isViewportAlreadySet = _isInitialViewSet || _globalIsInitialViewSet;
    final isViewportLocked = _globalViewportLocked;
    
    // 사용자 조작이 있었거나, 뷰포트가 이미 설정되었거나, 뷰포트가 잠겨있으면 설정하지 않음
    if (!isViewportAlreadySet && !hasAnyUserInteraction && !isViewportLocked) {
      print('📋 초기 뷰포트 설정 조건 체크:');
      print('   - _isInitialViewSet: $_isInitialViewSet');
      print('   - _globalIsInitialViewSet: $_globalIsInitialViewSet');
      print('   - _userHasInteracted: $_userHasInteracted');
      print('   - _globalUserHasInteracted: $_globalUserHasInteracted');
      print('   - _globalViewportLocked: $_globalViewportLocked');
      print('   - 데이터 개수: ${widget.summaryData.length}');
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // PostFrameCallback에서 다시 한 번 조건 체크
        final stillNoInteraction = !_userHasInteracted && !_globalUserHasInteracted;
        final stillNotSet = !_isInitialViewSet && !_globalIsInitialViewSet;
        final stillNotLocked = !_globalViewportLocked;
        
        if (mounted && stillNotSet && stillNoInteraction && stillNotLocked) {
          print('   ✅ 초기 뷰포트 설정 실행');
          setState(() {
            _setInitialViewport();
          });
        } else {
          print('   ❌ 초기 뷰포트 설정 건너뜀 (조건 변경됨)');
          print('      - mounted: $mounted');
          print('      - stillNotSet: $stillNotSet');
          print('      - stillNoInteraction: $stillNoInteraction');
          print('      - stillNotLocked: $stillNotLocked');
        }
      });
    } else {
      print('📋 초기 뷰포트 설정 완전 차단:');
      print('   - isViewportAlreadySet: $isViewportAlreadySet');
      print('   - hasAnyUserInteraction: $hasAnyUserInteraction');
      print('   - isViewportLocked: $isViewportLocked');
    }

    return Card(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.grey.shade50,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildLegendAndControls(),
              const SizedBox(height: 20),
              Container(
                height: 350,
                width: double.infinity,
                clipBehavior: Clip.hardEdge,
                decoration: const BoxDecoration(),
                child: _buildAdvancedChart(),
              ),
              const SizedBox(height: 16),
              _buildChartInfo(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      child: Container(
        height: 400,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              '차트 데이터가 없습니다',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '데이터를 불러오는 중이거나 선택된 기간에 데이터가 없습니다',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    // 제목 결정: 외부에서 제공된 title이 있으면 사용, 없으면 dataType에 따른 기본값
    final chartTitle = widget.title ?? 
        (_dataType == ChartDataType.actual 
            ? '외국인 실제 보유액 추이'
            : '외국인 순매수 누적 추이');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _dataType == ChartDataType.actual
                      ? [Colors.green.shade600, Colors.green.shade400] // 실제보유액은 녹색
                      : [Colors.blue.shade600, Colors.blue.shade400], // 누적순매수는 파랑
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _dataType == ChartDataType.actual 
                        ? Icons.account_balance_wallet // 실제보유액 아이콘
                        : Icons.trending_up, // 누적순매수 아이콘
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    chartTitle,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            const Spacer(),
            // 외부에서 강제로 chartDataType을 지정한 경우 버튼 숨김
            if (widget.chartDataType == null) ...[
              _buildDataTypeSelector(),
              const SizedBox(width: 8),
            ],
            _buildViewTypeSelector(),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _dataType == ChartDataType.actual
              ? '${widget.summaryData.length}일간의 실제 보유액 변화 (외국인 보유수량 × 주가)'
              : '${widget.summaryData.length}일간의 순매수 누적 변화 (+매수우세, -매도우세, 0=균형)',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildDataTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDataTypeButton(ChartDataType.actual, '실제보유액', Icons.account_balance_wallet),
          _buildDataTypeButton(ChartDataType.cumulative, '누적순매수', Icons.trending_up),
        ],
      ),
    );
  }

  Widget _buildViewTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildViewButton(ChartViewType.combined, '통합', Icons.show_chart),
          _buildViewButton(ChartViewType.separated, '분리', Icons.stacked_line_chart),
        ],
      ),
    );
  }

  Widget _buildDataTypeButton(ChartDataType type, String label, IconData icon) {
    final isSelected = _dataType == type;
    print('🏗️ 버튼 빌드됨: $label, isSelected=$isSelected, _dataType=$_dataType');
    
    return GestureDetector(
      onTap: () async {
        print('🔘 버튼 클릭됨: $label (type: $type)');
        print('🔘 현재 _dataType: $_dataType');
        print('🔘 현재 mounted: $mounted');
        print('🔘 현재 _isLoadingActualData: $_isLoadingActualData');
        print('🔘 isSelected: $isSelected (이미 선택되어 있으면 클릭해도 로딩하지 않음)');
        
        setState(() {
          _dataType = type;
          // 데이터 타입 변경도 사용자 조작으로 간주
          _userHasInteracted = true;
          _saveStateToGlobal();
        });
        
        // 실제보유액으로 변경 시 데이터 로드 (이미 선택되어 있어도 강제 로드)
        if (type == ChartDataType.actual && mounted) {
          print('🔄 실제보유액 버튼 클릭됨 - 데이터 로딩 시작');
          print('🔄 조건 확인: type==actual=${type == ChartDataType.actual}, mounted=$mounted');
          print('🔄 _isLoadingActualData 무시하고 강제 로드 진행');
          _isLoadingActualData = true;
          
          final provider = Provider.of<ForeignInvestorProvider>(context, listen: false);
          
          try {
            // 실제 보유액 데이터 로드 시도
            await provider.loadActualHoldingsData();
            print('🔄 실제보유액 데이터 로딩 완료 - 차트 업데이트');
            
            // 🔧 ChartHoldingsFixer로 차트 데이터 강제 수정
            print('🔧 버튼 클릭 후 ChartHoldingsFixer 실행');
            final wasFixed = await ChartHoldingsFixer.fixActualHoldingsValues(widget.summaryData);
            print('🔧 버튼 클릭 후 ChartHoldingsFixer 수정 결과: $wasFixed');
            
            // 수정이 성공했으면 차트 새로고침
            if (wasFixed && mounted) {
              print('🔄 버튼 클릭 후 차트 새로고침 실행');
              setState(() {
                // 강제로 다시 그리기
              });
            }
          } finally {
            _isLoadingActualData = false;
          }
          
          // 로드 실패 시에도 차트 모드는 변경되도록 함 (사용자 선택 존중)
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(provider.syncMessage?.contains('❌') == true 
                    ? '${provider.syncMessage} 재시도하려면 버튼을 다시 클릭하세요.'
                    : '실제 보유액 모드로 전환되었습니다.'),
                duration: const Duration(seconds: 3),
                backgroundColor: provider.syncMessage?.contains('❌') == true 
                    ? Colors.red.shade600 
                    : Colors.green.shade600,
              ),
            );
          }
        }
        
        _animationController.reset();
        _animationController.forward();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.shade600 : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewButton(ChartViewType type, String label, IconData icon) {
    final isSelected = _viewType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _viewType = type;
          // 뷰 타입 변경도 사용자 조작으로 간주
          _userHasInteracted = true;
          _saveStateToGlobal();
        });
        _animationController.reset();
        _animationController.forward();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade600 : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendAndControls() {
    return Column(
      children: [
        // 범례 - 상승/하강 색상 표시
        Row(
          children: [
            if (_viewType == ChartViewType.combined) ...[
              _buildLegendItem(Colors.red, '상승 구간', true, (value) {}),
              const SizedBox(width: 20),
              _buildLegendItem(Colors.blue, '하강 구간', true, (value) {}),
            ] else ...[
              _buildLegendItem(Colors.blue.shade600, 'KOSPI', _showKospiData, (value) {
                setState(() => _showKospiData = value);
              }),
              const SizedBox(width: 20),
              _buildLegendItem(Colors.orange.shade600, 'KOSDAQ', _showKosdaqData, (value) {
                setState(() => _showKosdaqData = value);
              }),
            ],
          ],
        ),
        const SizedBox(height: 12),
        // 제스처 가이드
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.touch_app, size: 14, color: Colors.blue.shade600),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '터치: 상세정보 • 핀치: 확대/축소 • 좌측 드래그: 과거 • 우측 드래그: 최신',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label, bool isVisible, Function(bool) onChanged) {
    return GestureDetector(
      onTap: () {
        onChanged(!isVisible);
        // 범례 토글도 사용자 조작으로 간주
        _userHasInteracted = true;
        _saveStateToGlobal();
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: isVisible ? color : Colors.grey.shade300,
              shape: BoxShape.circle,
              boxShadow: isVisible ? [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ] : null,
            ),
            child: isVisible ? Icon(
              Icons.check,
              size: 10,
              color: Colors.white,
            ) : null,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isVisible ? Colors.black87 : Colors.grey.shade500,
                fontWeight: isVisible ? FontWeight.w600 : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedChart() {
    // 초기 뷰포트 설정 조건 체크 - 더 엄격하게
    if (!_isInitialViewSet && 
        !_globalIsInitialViewSet && 
        !_userHasInteracted && 
        !_globalUserHasInteracted && 
        !_globalViewportLocked && 
        widget.summaryData.isNotEmpty) {
      _setInitialViewport();
    }
    
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Stack(
            children: [
              // 메인 차트
              GestureDetector(
                onScaleStart: (details) {
                  _lastPanX = _panX;
                  _hideTooltip();
                  // 사용자가 조작을 시작했음을 표시
                  _userHasInteracted = true;
                  _saveStateToGlobal();
                },
                onScaleUpdate: (details) {
                  setState(() {
                    _scale = (_scale * details.scale).clamp(0.5, 5.0);
                    
                    if (details.scale == 1.0) {
                      // 핑거 제스처 개선: 좌측으로 드래그하면 과거 데이터, 우측으로 드래그하면 최신 데이터
                      final deltaX = details.focalPointDelta.dx;
                      _panX = _lastPanX + deltaX;
                      
                      // 팬 범위 제한 계산 개선
                      final screenWidth = MediaQuery.of(context).size.width;
                      final chartWidth = screenWidth - 120; // 여백 고려
                      final scaledWidth = chartWidth * _scale;
                      final dataWidth = widget.summaryData.length > 1 
                          ? scaledWidth
                          : chartWidth;
                      
                      // 팬 범위: 
                      // - 왼쪽 한계: 모든 과거 데이터가 보이도록
                      // - 오른쪽 한계: 최신 데이터가 항상 보이도록
                      final maxPanLeft = -(dataWidth - chartWidth).clamp(0.0, double.infinity);
                      const maxPanRight = 0.0; // 최신 데이터 위치 고정
                      
                      _panX = _panX.clamp(maxPanLeft, maxPanRight);
                      
                      // 사용자가 과거 데이터 영역에 가까이 가면 더 많은 데이터 로드 요청
                      if (_panX < maxPanLeft * 0.8) { // 80% 지점에서 트리거
                        _requestMoreHistoricalData();
                      }
                    }
                    
                    // 상태 변경 시마다 전역에 저장
                    _saveStateToGlobal();
                  });
                },
                onTapDown: (details) {
                  _handleChartTap(details.localPosition);
                },
                child: ClipRect(
                  child: SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                    child: CustomPaint(
                      painter: _AdvancedChartPainter(
                        data: widget.summaryData,
                        scale: _scale,
                        panX: _panX,
                        viewType: _viewType,
                        dataType: _dataType,
                        showKospi: _showKospiData,
                        showKosdaq: _showKosdaqData,
                        showCombined: _showCombinedData,
                        animationValue: _fadeAnimation.value,
                      ),
                    ),
                  ),
                ),
              ),
              
              // Y축 라벨
              Positioned(
                left: 0,
                top: 0,
                bottom: 40,
                width: 80,
                child: ClipRect(child: _buildYAxisLabels()),
              ),
              
              // X축 라벨
              Positioned(
                left: 80,
                right: 0,
                bottom: 0,
                height: 40,
                child: ClipRect(child: _buildXAxisLabels()),
              ),
              
              // 툴팁
              if (_showTooltip && _tooltipPosition != null && _selectedData != null)
                Positioned(
                  left: _tooltipPosition!.dx,
                  top: _tooltipPosition!.dy,
                  child: AnimatedBuilder(
                    animation: _tooltipAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _tooltipAnimation.value,
                        child: _buildTooltip(_selectedData!),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _handleChartTap(Offset position) {
    // 차트 영역 내의 탭인지 확인
    if (position.dx < 80 || position.dy > 310) return;
    
    // 🔧 그래프와 동일한 방식으로 데이터 정렬
    final sortedData = List<DailyForeignSummary>.from(widget.summaryData);
    sortedData.sort((a, b) => a.date.compareTo(b.date));
    
    // 가장 가까운 데이터 포인트 찾기
    final screenWidth = MediaQuery.of(context).size.width;
    final chartWidth = screenWidth - 120;
    final dataIndex = _findNearestDataIndex(position.dx - 80, chartWidth, sortedData);
    
    if (dataIndex >= 0 && dataIndex < sortedData.length) {
      final selectedData = sortedData[dataIndex];
      
      // 🔍 디버깅: 클릭된 데이터와 실제 그래프 값 확인
      print('🖱️ 차트 클릭 정보:');
      print('   - 클릭 위치: x=${position.dx.toStringAsFixed(1)}, y=${position.dy.toStringAsFixed(1)}');
      print('   - 데이터 인덱스: $dataIndex');
      print('   - 선택된 데이터: ${selectedData.date} ${selectedData.marketType}');
      print('   - actualHoldingsValue: ${selectedData.actualHoldingsValue} (${(selectedData.actualHoldingsValue / 1000000000000).toStringAsFixed(1)}조원)');
      print('   - cumulativeHoldings: ${selectedData.cumulativeHoldings}');
      
      // 클릭한 Y 위치에서 실제 값 계산 (실제 데이터 범위 사용)
      final values = _dataType == ChartDataType.actual
          ? sortedData.map((d) => d.actualHoldingsValue).toList()
          : sortedData.map((d) => d.cumulativeHoldings).toList();
          
      if (values.isNotEmpty) {
        final minValue = values.reduce(math.min).toDouble();
        final maxValue = values.reduce(math.max).toDouble();
        final range = maxValue - minValue;
        
        // 차트 영역 정보
        final chartRect = Rect.fromLTWH(80, 20, MediaQuery.of(context).size.width - 120, MediaQuery.of(context).size.height - 180);
        
        // 클릭한 Y 좌표를 실제 값으로 역변환
        // Y축은 위로 갈수록 큰 값이므로: y가 작을수록 큰 값
        final normalizedY = (chartRect.bottom - position.dy) / chartRect.height;
        final clickedValue = minValue + (normalizedY * range);
        
        print('   - 실제 데이터 범위: ${(minValue / 1000000000000).toStringAsFixed(1)}조 ~ ${(maxValue / 1000000000000).toStringAsFixed(1)}조');
        print('   - 클릭한 Y 위치는 약 ${(clickedValue / 1000000000000).toStringAsFixed(1)}조 지점');
      }
      
      setState(() {
        _selectedData = selectedData; // 정렬된 데이터 사용
        _tooltipPosition = Offset(
          (position.dx - 100).clamp(10, screenWidth - 210),
          (position.dy - 80).clamp(10, 200),
        );
        _showTooltip = true;
      });
      
      _tooltipController.reset();
      _tooltipController.forward();
      
      // 3초 후 툴팁 자동 숨김
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          _hideTooltip();
        }
      });
    }
  }

  int _findNearestDataIndex(double x, double chartWidth, List<DailyForeignSummary> sortedData) {
    if (sortedData.isEmpty) return 0;
    
    final clampedScale = _scale.clamp(0.01, 100.0); // Prevent division by very small numbers
    final scaledWidth = chartWidth * clampedScale;
    final pointSpacing = sortedData.length > 1 
        ? (scaledWidth / (sortedData.length - 1)).clamp(0.1, double.infinity)
        : (scaledWidth / 2).clamp(0.1, double.infinity);
    
    final adjustedX = x - _panX;
    final index = (adjustedX / pointSpacing).round();
    
    return index.clamp(0, sortedData.length - 1);
  }

  void _hideTooltip() {
    if (_showTooltip) {
      setState(() {
        _showTooltip = false;
      });
    }
  }

  // 더 많은 과거 데이터 요청
  void _requestMoreHistoricalData() {
    // 과도한 요청 방지를 위해 쓰로틀링
    if (_lastHistoricalDataRequest != null && 
        DateTime.now().difference(_lastHistoricalDataRequest!) < const Duration(seconds: 2)) {
      return;
    }
    
    _lastHistoricalDataRequest = DateTime.now();
    
    // Provider를 통해 과거 데이터 로드 요청
    try {
      // context가 유효한지 확인
      if (!mounted) return;
      
      
      // ForeignInvestorProvider의 loadMoreHistoricalData 메서드 호출
      if (widget.onRequestMoreData != null) {
        widget.onRequestMoreData!();
      } else {
        // 콜백이 없으면 기본 동작
        Future.microtask(() {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('과거 데이터를 불러오는 중...'),
                duration: Duration(seconds: 1),
              ),
            );
          }
        });
      }
    } catch (e) {
    }
  }

  DateTime? _lastHistoricalDataRequest;

  // 초기 뷰포트 설정 (60일 전부터 현재까지 표시) - 최초 1회만
  void _setInitialViewport() {
    // 뷰포트 설정 조건을 다시 한 번 체크 (중요!)
    if (widget.summaryData.isEmpty || 
        _userHasInteracted || 
        _globalUserHasInteracted || 
        _isInitialViewSet || 
        _globalIsInitialViewSet ||
        _globalViewportLocked) {
      print('❌ 초기 뷰포트 설정 중단');
      print('   - summaryData.isEmpty: ${widget.summaryData.isEmpty}');
      print('   - _userHasInteracted: $_userHasInteracted');
      print('   - _globalUserHasInteracted: $_globalUserHasInteracted');
      print('   - _isInitialViewSet: $_isInitialViewSet');
      print('   - _globalIsInitialViewSet: $_globalIsInitialViewSet');
      print('   - _globalViewportLocked: $_globalViewportLocked');
      return;
    }
    
    print('🔄 초기 뷰포트 설정 실행 중...');
    
    // 데이터를 날짜순으로 정렬 (과거 -> 최신)
    final sortedData = List<DailyForeignSummary>.from(widget.summaryData);
    sortedData.sort((a, b) => a.date.compareTo(b.date));
    
    // 화면 크기 계산
    final screenWidth = MediaQuery.of(context).size.width;
    final chartWidth = screenWidth - 120; // 여백 고려
    
    // 전체 데이터 길이가 60일보다 많으면 최근 60일만 보이도록 조정
    if (sortedData.length > 60) {
      // 전체 데이터에서 최근 60일이 화면에 맞도록 스케일과 팬 조정
      final visibleDataRatio = 60.0 / sortedData.length;
      _scale = (1.0 / visibleDataRatio).clamp(1.0, 5.0);
      
      // 최신 데이터(오른쪽 끝)이 보이도록 팬 위치 조정
      final scaledWidth = chartWidth * _scale;
      _panX = -(scaledWidth - chartWidth);
      
      print('📊 데이터 ${sortedData.length}개 → 최근 60일 표시 (scale: ${_scale.toStringAsFixed(2)})');
    } else {
      // 60일 이하면 전체 데이터 표시
      _scale = 1.0;
      _panX = 0.0;
      
      print('📊 전체 데이터 ${sortedData.length}개 표시');
    }
    
    _isInitialViewSet = true;
    _saveStateToGlobal();
  }

  Widget _buildTooltip(DailyForeignSummary data) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatDate(data.date),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _dataType == ChartDataType.actual
                ? (data.actualHoldingsValue > 0 
                    ? '실제 보유액: ${_formatAmount(data.actualHoldingsValue)}'
                    : '실제 보유액: 데이터 로딩 중...')
                : '누적 순매수: ${_formatAmount(data.cumulativeHoldings)}${data.cumulativeHoldings > 0 ? " (매수우세)" : data.cumulativeHoldings < 0 ? " (매도우세)" : " (균형)"}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          Text(
            '순매수: ${_formatAmount(data.totalForeignNetAmount)}',
            style: TextStyle(
              color: data.totalForeignNetAmount > 0 ? Colors.green.shade300 : Colors.red.shade300,
              fontSize: 11,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          Text(
            '거래액: ${_formatAmount(data.foreignTotalTradeAmount)}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildYAxisLabels() {
    final values = _dataType == ChartDataType.actual
        ? widget.summaryData.map((d) => d.actualHoldingsValue).toList()
        : widget.summaryData.map((d) => d.cumulativeHoldings).toList();
        
    // 디버깅: Y축 라벨에서 읽는 실제 값들 확인
    if (_dataType == ChartDataType.actual) {
      print('📊 Y축에서 읽는 actualHoldingsValue 값들:');
      for (int i = 0; i < math.min(values.length, 5); i++) {
        final data = widget.summaryData[i];
        print('  - [${data.date}] ${data.marketType}: ${data.actualHoldingsValue} (${(data.actualHoldingsValue / 1000000000000).toStringAsFixed(1)}조원)');
      }
      
      final zeroCount = values.where((v) => v == 0).length;
      final nonZeroCount = values.where((v) => v > 0).length;
      print('📊 Y축 실제보유액 통계: 0인 값=${zeroCount}개, 0이 아닌 값=${nonZeroCount}개, 전체=${values.length}개');
      print('📊 Y축 값 범위: min=${values.isNotEmpty ? values.reduce(math.min) : 0}, max=${values.isNotEmpty ? values.reduce(math.max) : 0}');
    }
    
    if (_dataType == ChartDataType.actual) {
      print('🔍 차트에서 실제 보유액 값들: ${values.take(3).map((v) => "${v ~/ 1000000000000}조").toList()}');
    }
    
    if (values.isEmpty) return const SizedBox();
    
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final range = maxValue - minValue;
    
    // range가 0이거나 NaN인 경우 처리
    if (range == 0 || range.isNaN || range.isInfinite) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(
              _dataType == ChartDataType.actual ? '(실제보유액)' : '(누적순매수)',
              style: TextStyle(
                fontSize: 8,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(
              _formatAxisValue(maxValue.toInt()),
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
    }
    
    // 🔧 간단하고 정확한 Y축 간격 계산
    const stepCount = 6;
    final step = range / (stepCount - 1);
    
    print('🔧 Y축 라벨 계산:');
    print('   - 데이터 범위: ${(minValue / 1000000000000).toStringAsFixed(1)}조 ~ ${(maxValue / 1000000000000).toStringAsFixed(1)}조');
    print('   - 스텝 크기: ${(step / 1000000000000).toStringAsFixed(2)}조');
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Y축 단위 라벨
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Text(
            _dataType == ChartDataType.actual ? '(실제보유액)' : '(누적순매수)',
            style: TextStyle(
              fontSize: 8,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        ...List.generate(stepCount, (index) {
          // 🔧 Y축 라벨: 위로 갈수록 큰 값 (오름차순 고정)
          final value = minValue + (step * (stepCount - 1 - index));
          final formattedValue = _formatAxisValue(value.toInt());
          
          // 처음 3개 라벨만 디버깅 출력
          if (index < 3) {
            print('   - 라벨[$index]: ${(value / 1000000000000).toStringAsFixed(1)}조 ($formattedValue)');
          }
          
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(
              formattedValue,
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          );
        }),
      ],
    );
  }

  // Y축 값의 적절한 단위로 포맷팅 (마이너스 기호 제거)
  String _formatAxisValue(int value) {
    final absValue = value.abs();
    
    if (absValue >= 1000000000000) { // 1조 이상
      final trillion = absValue / 1000000000000;
      if (trillion >= 100) {
        return '${trillion.toStringAsFixed(0)}조';
      } else if (trillion >= 10) {
        return '${trillion.toStringAsFixed(1)}조';
      } else {
        return '${trillion.toStringAsFixed(2)}조';
      }
    } else if (absValue >= 100000000000) { // 1000억 이상
      final hundredBillion = absValue / 100000000000;
      return '${hundredBillion.toStringAsFixed(1)}천억';
    } else if (absValue >= 100000000) { // 1억 이상
      final billion = absValue / 100000000;
      return '${billion.toStringAsFixed(0)}억';
    } else if (absValue >= 10000) { // 1만 이상
      final million = absValue / 10000;
      return '${million.toStringAsFixed(0)}만';
    } else {
      return '$absValue';
    }
  }

  // 수치의 크기(magnitude) 계산
  int _getMagnitude(double value) {
    if (value == 0) return 1;
    int magnitude = 1;
    final absValue = value.abs();
    
    if (absValue >= 1) {
      while (magnitude * 10 <= absValue) {
        magnitude *= 10;
      }
    } else {
      while (magnitude > absValue * 10) {
        magnitude = (magnitude / 10).round();
      }
    }
    return magnitude;
  }

  Widget _buildXAxisLabels() {
    if (widget.summaryData.isEmpty) return const SizedBox();
    
    // 스케일과 화면 크기에 따른 적응적 라벨 개수 계산
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - 120; // 여백 고려
    final clampedScale = _scale.clamp(0.01, 100.0);
    
    // 라벨간 최소 간격을 60픽셀로 설정
    final maxLabels = (availableWidth / 60).floor().clamp(3, 8);
    final visibleDataCount = (widget.summaryData.length / clampedScale).round().clamp(3, widget.summaryData.length);
    final actualLabelCount = math.min(maxLabels, visibleDataCount);
    
    // 데이터를 시간순으로 정렬 (과거 -> 최신)
    final sortedData = List<DailyForeignSummary>.from(widget.summaryData);
    sortedData.sort((a, b) => a.date.compareTo(b.date));
    
    // 현재 표시되는 데이터 범위 계산 (팬 위치 고려)
    
    // 표시할 라벨의 인덱스들 계산
    final labelIndices = <int>[];
    if (actualLabelCount > 0) {
      final step = (sortedData.length - 1) / (actualLabelCount - 1);
      for (int i = 0; i < actualLabelCount; i++) {
        final index = (i * step).round().clamp(0, sortedData.length - 1);
        if (!labelIndices.contains(index)) {
          labelIndices.add(index);
        }
      }
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: labelIndices.map((index) {
          final data = sortedData[index];
          final displayDate = _formatDateForAxis(data.date);
          
          return Expanded(
            child: Text(
              displayDate,
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          );
        }).toList(),
      ),
    );
  }

  // X축용 날짜 포맷팅 (더 읽기 쉽게)
  String _formatDateForAxis(String date) {
    if (date.length < 8) return date;
    
    final year = date.substring(0, 4);
    final month = date.substring(4, 6);
    final day = date.substring(6, 8);
    
    // 현재 년도와 비교하여 년도 표시 여부 결정
    final currentYear = DateTime.now().year.toString();
    
    if (year == currentYear) {
      // 올해 데이터는 월/일만 표시
      return '$month/$day';
    } else {
      // 다른 년도는 년/월 표시
      return '$year/$month월';
    }
  }

  Widget _buildChartInfo() {
    if (widget.summaryData.isEmpty) return const SizedBox();
    
    try {
      final latest = widget.summaryData.first;
      final earliest = widget.summaryData.last;
      
      final currentValue = _dataType == ChartDataType.actual 
          ? latest.actualHoldingsValue 
          : latest.cumulativeHoldings;
      final earliestValue = _dataType == ChartDataType.actual 
          ? earliest.actualHoldingsValue 
          : earliest.cumulativeHoldings;
      
      final change = currentValue - earliestValue;
      final changePercent = earliestValue != 0 
          ? (change / earliestValue * 100) 
          : 0.0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildInfoItem(
              _dataType == ChartDataType.actual ? '현재 실제 보유액' : '현재 누적 순매수',
              _formatAmount(currentValue),
              Colors.blue.shade600,
              _dataType == ChartDataType.actual ? Icons.account_balance_wallet : Icons.trending_up,
            ),
          ),
          Container(width: 1, height: 40, color: Colors.grey.shade300),
          Expanded(
            child: _buildInfoItem(
              '기간 변화',
              '${change > 0 ? '+' : ''}${_formatAmount(change)}',
              change > 0 ? Colors.green.shade600 : Colors.red.shade600,
              change > 0 ? Icons.trending_up : Icons.trending_down,
            ),
          ),
          Container(width: 1, height: 40, color: Colors.grey.shade300),
          Expanded(
            child: _buildInfoItem(
              '변화율',
              '${change > 0 ? '+' : ''}${changePercent.toStringAsFixed(1)}%',
              change > 0 ? Colors.green.shade600 : Colors.red.shade600,
              Icons.percent,
            ),
          ),
        ],
      ),
    );
    } catch (e) {
      return const SizedBox(); // Return empty widget if data access fails
    }
  }

  Widget _buildInfoItem(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  String _formatDate(String date) {
    if (date.length >= 8) {
      return '${date.substring(0, 4)}-${date.substring(4, 6)}-${date.substring(6, 8)}';
    }
    return date;
  }

  String _formatAmount(int amount) {
    final absAmount = amount.abs();
    final sign = amount < 0 ? '-' : '';
    
    if (absAmount >= 1000000000000) {
      return '$sign${(absAmount / 1000000000000).toStringAsFixed(1)}조원';
    } else if (absAmount >= 100000000) {
      return '$sign${(absAmount / 100000000).toStringAsFixed(0)}억원';
    } else if (absAmount >= 10000) {
      return '$sign${(absAmount / 10000).toStringAsFixed(0)}만원';
    } else {
      return '$sign$absAmount원';
    }
  }
}

enum ChartViewType { combined, separated }
enum ChartDataType { cumulative, actual } // 누적 순매수 vs 실제 보유액

class _AdvancedChartPainter extends CustomPainter {
  final List<DailyForeignSummary> data;
  final double scale;
  final double panX;
  final ChartViewType viewType;
  final ChartDataType dataType;
  final bool showKospi;
  final bool showKosdaq;
  final bool showCombined;
  final double animationValue;

  _AdvancedChartPainter({
    required this.data,
    required this.scale,
    required this.panX,
    required this.viewType,
    required this.dataType,
    required this.showKospi,
    required this.showKosdaq,
    required this.showCombined,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || size.width <= 0 || size.height <= 0) return;

    // Ensure safe dimensions
    final safeWidth = size.width.clamp(80.0, double.infinity);
    final safeHeight = size.height.clamp(40.0, double.infinity);
    final chartArea = Rect.fromLTWH(
      80, 
      0, 
      (safeWidth - 80).clamp(1.0, double.infinity), 
      (safeHeight - 40).clamp(1.0, double.infinity)
    );
    
    // 강력한 클리핑 적용 - 차트 영역만 그리기 허용
    canvas.save();
    canvas.clipRect(chartArea);

    _drawGrid(canvas, chartArea);
    
    if (viewType == ChartViewType.combined && showCombined) {
      _drawCombinedChart(canvas, chartArea);
    } else {
      if (showKospi) _drawKospiChart(canvas, chartArea);
      if (showKosdaq) _drawKosdaqChart(canvas, chartArea);
    }

    canvas.restore();
  }

  void _drawGrid(Canvas canvas, Rect chartArea) {
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeWidth = 0.5;

    // 수평 그리드
    for (int i = 0; i <= 5; i++) {
      final y = chartArea.top + (chartArea.height * i / 5);
      canvas.drawLine(
        Offset(chartArea.left, y),
        Offset(chartArea.right, y),
        gridPaint,
      );
    }
    
    // 0 기준선 강조 (누적 순매수 모드에서만)
    if (dataType == ChartDataType.cumulative) {
      final values = data.map((d) => d.cumulativeHoldings).toList();
      if (values.isNotEmpty) {
        final maxValue = values.reduce((a, b) => a > b ? a : b);
        final minValue = values.reduce((a, b) => a < b ? a : b);
        
        // 0이 차트 범위 내에 있으면 0 기준선 그리기
        if (minValue <= 0 && maxValue >= 0) {
          final range = maxValue - minValue;
          if (range > 0) {
            // 🔧 0 기준선 계산: 위로 갈수록 큰 값
            final zeroY = chartArea.bottom - ((0 - minValue) / range * chartArea.height);
            final zeroLinePaint = Paint()
              ..color = Colors.red.withOpacity(0.7)
              ..strokeWidth = 1.5
              ..style = PaintingStyle.stroke;
            
            canvas.drawLine(
              Offset(chartArea.left, zeroY),
              Offset(chartArea.right, zeroY),
              zeroLinePaint,
            );
            
            // 0 라벨 추가
            final textPainter = TextPainter(
              text: TextSpan(
                text: '0 (균형)',
                style: TextStyle(
                  color: Colors.red.shade600,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              textDirection: TextDirection.ltr,
            );
            textPainter.layout();
            textPainter.paint(canvas, Offset(chartArea.left - 75, zeroY - 6));
          }
        }
      }
    }

    // 수직 그리드
    final visiblePoints = (data.length / scale).round().clamp(5, data.length);
    for (int i = 0; i <= visiblePoints; i++) {
      final x = chartArea.left + panX + (chartArea.width * scale * i / visiblePoints);
      if (x >= chartArea.left && x <= chartArea.right) {
        canvas.drawLine(
          Offset(x, chartArea.top),
          Offset(x, chartArea.bottom),
          gridPaint,
        );
      }
    }
  }

  void _drawCombinedChart(Canvas canvas, Rect chartArea) {
    final values = dataType == ChartDataType.actual
        ? data.map((d) => d.actualHoldingsValue).toList()
        : data.map((d) => d.cumulativeHoldings).toList();
    
    // 디버깅: 차트 그리기에서 실제 값들 확인
    if (dataType == ChartDataType.actual) {
      print('🎨 차트 그리기에서 읽는 actualHoldingsValue 값들:');
      for (int i = 0; i < math.min(values.length, 5); i++) {
        final data_item = data[i];
        print('  - [${data_item.date}] ${data_item.marketType}: ${data_item.actualHoldingsValue} (${(data_item.actualHoldingsValue / 1000000000000).toStringAsFixed(1)}조원)');
      }
      
      final zeroCount = values.where((v) => v == 0).length;
      final nonZeroCount = values.where((v) => v > 0).length;
      print('🎨 차트 그리기 실제보유액 통계: 0인 값=${zeroCount}개, 0이 아닌 값=${nonZeroCount}개, 전체=${values.length}개');
      print('🎨 values.every((v) => v == 0) = ${values.every((v) => v == 0)}');
    }
    
    if (values.isEmpty) return;
    
    // 실제 보유액 모드에서 모든 값이 0인 경우 DB 데이터 로딩 시도 후 메시지 표시
    if (dataType == ChartDataType.actual && values.every((v) => v == 0)) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'DB에서 실제 보유액 데이터 로딩 중...\n잠시만 기다려주세요.',
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      textPainter.layout();
      
      final centerX = chartArea.left + chartArea.width / 2 - textPainter.width / 2;
      final centerY = chartArea.top + chartArea.height / 2 - textPainter.height / 2;
      textPainter.paint(canvas, Offset(centerX, centerY));
      return;
    }

    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final rawRange = maxValue - minValue;
    final range = rawRange == 0 ? 1.0 : rawRange.abs().clamp(0.001, double.infinity);

    // 🔍 디버깅: Y축 계산 정보 출력
    print('🔍 차트 Y축 계산 정보:');
    print('   - minValue: $minValue (${(minValue / 1000000000000).toStringAsFixed(1)}조원)');
    print('   - maxValue: $maxValue (${(maxValue / 1000000000000).toStringAsFixed(1)}조원)');
    print('   - range: $range (${(range / 1000000000000).toStringAsFixed(1)}조원)');
    print('   - chartArea.top: ${chartArea.top}');
    print('   - chartArea.bottom: ${chartArea.bottom}');
    print('   - chartArea.height: ${chartArea.height}');
    
    // Y축 라벨 값 계산 시뮬레이션: 위로 갈수록 큰 값
    print('🔍 Y축 라벨 예상 값들 (위로 갈수록 큰 값):');
    final stepCount = 6;
    for (int i = 0; i < stepCount; i++) {
      // 위로 갈수록 큰 값이므로 역순 계산
      final labelValue = minValue + (range * (stepCount - 1 - i) / (stepCount - 1));
      final labelPosition = chartArea.top + (i * chartArea.height / (stepCount - 1));
      print('   - 라벨[$i]: ${(labelValue / 1000000000000).toStringAsFixed(1)}조 at y=${labelPosition.toStringAsFixed(1)}');
    }

    final sortedData = List<DailyForeignSummary>.from(data);
    sortedData.sort((a, b) => a.date.compareTo(b.date));

    final points = <Offset>[];
    final clampedScale = scale.clamp(0.01, 100.0);
    final scaledWidth = chartArea.width * clampedScale;
    final pointSpacing = sortedData.length > 1 
        ? (scaledWidth / (sortedData.length - 1)).clamp(0.1, double.infinity)
        : (scaledWidth / 2).clamp(0.1, double.infinity);

    for (int i = 0; i < sortedData.length; i++) {
      final x = chartArea.left + panX + (i * pointSpacing);
      final value = dataType == ChartDataType.actual 
          ? sortedData[i].actualHoldingsValue 
          : sortedData[i].cumulativeHoldings;
      final normalizedValue = ((value - minValue) / range).clamp(0.0, 1.0);
      // 🔧 Y축 라벨과 일치: 위로 갈수록 큰 값 (큰 값이 위쪽=작은 y좌표)
      final y = chartArea.bottom - (normalizedValue * chartArea.height);
      // Y축 범위를 더 엄격하게 제한 (5px 여유 공간)
      final clampedY = y.clamp(chartArea.top + 5, chartArea.bottom - 5);
      
      // 🔍 첫 3개 포인트 계산 과정 로그
      if (i < 3) {
        print('🔍 포인트[$i] 계산: ${sortedData[i].date}');
        print('   - 실제값: $value (${(value / 1000000000000).toStringAsFixed(1)}조원)');
        print('   - normalized: ${normalizedValue.toStringAsFixed(3)}');
        print('   - y위치: ${y.toStringAsFixed(1)} (위로 갈수록 큰 값)');
      }
      
      points.add(Offset(x, clampedY));
    }

    _drawAnimatedLine(canvas, points, Colors.blue.shade600, 3.0);
    _drawAnimatedArea(canvas, points, chartArea, Colors.grey.withOpacity(0.1)); // 중성적인 배경색
    _drawAnimatedPoints(canvas, points, sortedData, Colors.blue.shade600);
  }

  void _drawKospiChart(Canvas canvas, Rect chartArea) {
    // KOSPI 데이터만 필터링하여 그리기
    _drawMarketChart(canvas, chartArea, 'KOSPI', Colors.blue.shade600);
  }

  void _drawKosdaqChart(Canvas canvas, Rect chartArea) {
    // KOSDAQ 데이터만 필터링하여 그리기
    _drawMarketChart(canvas, chartArea, 'KOSDAQ', Colors.orange.shade600);
  }

  void _drawMarketChart(Canvas canvas, Rect chartArea, String market, Color color) {
    final marketData = data.where((d) => d.marketType == market).toList();
    if (marketData.isEmpty) return;

    final values = dataType == ChartDataType.actual
        ? marketData.map((d) => d.actualHoldingsValue).toList()
        : marketData.map((d) => d.cumulativeHoldings).toList();
    if (values.isEmpty) return;
    
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final rawRange = maxValue - minValue;
    final range = rawRange == 0 ? 1.0 : rawRange.abs().clamp(0.001, double.infinity);

    final sortedData = List<DailyForeignSummary>.from(marketData);
    sortedData.sort((a, b) => a.date.compareTo(b.date));

    final points = <Offset>[];
    final clampedScale = scale.clamp(0.01, 100.0);
    final scaledWidth = chartArea.width * clampedScale;
    final pointSpacing = sortedData.length > 1 
        ? (scaledWidth / (sortedData.length - 1)).clamp(0.1, double.infinity)
        : (scaledWidth / 2).clamp(0.1, double.infinity);

    for (int i = 0; i < sortedData.length; i++) {
      final x = chartArea.left + panX + (i * pointSpacing);
      final value = dataType == ChartDataType.actual 
          ? sortedData[i].actualHoldingsValue 
          : sortedData[i].cumulativeHoldings;
      final normalizedValue = ((value - minValue) / range).clamp(0.0, 1.0);
      // 🔧 Y축 라벨과 일치: 위로 갈수록 큰 값 (큰 값이 위쪽=작은 y좌표)
      final y = chartArea.bottom - (normalizedValue * chartArea.height);
      // Y축 범위를 더 엄격하게 제한 (5px 여유 공간)
      final clampedY = y.clamp(chartArea.top + 5, chartArea.bottom - 5);
      points.add(Offset(x, clampedY));
    }

    _drawAnimatedLine(canvas, points, color, 2.5);
    _drawAnimatedPoints(canvas, points, sortedData, color);
  }

  void _drawAnimatedLine(Canvas canvas, List<Offset> points, Color baseColor, double strokeWidth) {
    if (points.isEmpty || points.length < 2) return;

    // 각 구간별로 상승/하강에 따라 색상을 다르게 그리기
    for (int i = 0; i < points.length - 1; i++) {
      final animatedIndex = ((i + 1) * animationValue).floor();
      if (animatedIndex <= i) continue;
      
      final startPoint = points[i];
      final endPoint = points[i + 1];
      
      // 상승/하강 판단 (y값이 작을수록 위쪽)
      final isRising = endPoint.dy < startPoint.dy;
      final segmentColor = isRising ? Colors.red : Colors.blue;
      
      final paint = Paint()
        ..color = segmentColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      // 직선으로 그리기 (더 명확한 색상 구분)
      canvas.drawLine(startPoint, endPoint, paint);
    }
  }

  void _drawAnimatedArea(Canvas canvas, List<Offset> points, Rect chartArea, Color color) {
    if (points.isEmpty || points.length < 2) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    // 🔧 Y축 수정으로 인해 area 그리기도 수정 필요
    path.moveTo(points[0].dx, chartArea.bottom);
    path.lineTo(points[0].dx, points[0].dy);

    for (int i = 1; i < (points.length * animationValue).floor(); i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    final lastIndex = (points.length * animationValue).floor() - 1;
    if (lastIndex >= 0 && lastIndex < points.length) {
      path.lineTo(points[lastIndex].dx, chartArea.bottom);
    }
    path.close();

    canvas.drawPath(path, paint);
  }

  void _drawAnimatedPoints(Canvas canvas, List<Offset> points, List<DailyForeignSummary> sortedData, Color baseColor) {
    if (points.isEmpty || sortedData.isEmpty) return;
    
    final borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final maxIndex = (points.length * animationValue).floor().clamp(0, points.length);
    for (int i = 0; i < maxIndex; i++) {
      if (i >= points.length) break;
      
      final point = points[i];
      // 포인트가 차트 영역 안에 있고, 여유 공간을 고려해서 그리기
      if (point.dx >= 80 && point.dy >= 10 && point.dy <= 340) {
        
        // 상승/하강에 따른 포인트 색상 결정
        Color pointColor = baseColor; // 기본 색상
        
        if (i > 0 && i < sortedData.length) {
          final prevValue = i > 0 
              ? (dataType == ChartDataType.actual 
                  ? sortedData[i - 1].actualHoldingsValue 
                  : sortedData[i - 1].cumulativeHoldings)
              : 0;
          final currentValue = dataType == ChartDataType.actual 
              ? sortedData[i].actualHoldingsValue 
              : sortedData[i].cumulativeHoldings;
          final isIncrease = currentValue > prevValue;
          pointColor = isIncrease ? Colors.red : Colors.blue;
        }
        
        final pointPaint = Paint()
          ..color = pointColor
          ..style = PaintingStyle.fill;
        
        // 큰 원 그리기
        canvas.drawCircle(point, 4.0, pointPaint);
        canvas.drawCircle(point, 4.0, borderPaint);
        
        // 내부 강조 원 (더 작은 원으로 색상 강조)
        final innerPaint = Paint()
          ..color = pointColor.withOpacity(0.8)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(point, 2.0, innerPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}