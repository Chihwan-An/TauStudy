#!/bin/bash

# 환경변수에서 파일 경로를 가져옴
MYFILE="$MYFILE"

# 디버깅: 파일 경로 확인
echo "=== 디버깅 정보 ==="
echo "MYFILE 환경변수: $MYFILE"
echo "첫 번째 인수: $1"
echo "현재 디렉토리: $(pwd)"
echo "=================="

# 파일 경로 검증
if [ -z "$MYFILE" ]; then
    echo "오류: MYFILE 환경변수가 설정되지 않았습니다!"
    exit 1
fi

if [ ! -f "$MYFILE" ]; then
    echo "오류: 파일이 존재하지 않습니다: $MYFILE"
    exit 1
fi

echo "처리할 파일: $MYFILE"

cd /data6/Users/achihwan/CMSSW_16_0_0_pre2/src
source /cvmfs/cms.cern.ch/cmsset_default.sh
# SITECONF 파일 존재 여부 확인 및 내용 출력
SITECONF_FILE="/cvmfs/cms.cern.ch/SITECONF/local/JobConfig/site-local-config.xml"

echo "=== SITECONF 파일 확인 ==="
if [ -f "$SITECONF_FILE" ]; then
    echo "✅ SITECONF 파일이 존재합니다: $SITECONF_FILE"
    echo "--- 파일 내용 ---"
    cat "$SITECONF_FILE"
    echo "--- 파일 내용 끝 ---"
else
    echo "❌ SITECONF 파일이 존재하지 않습니다: $SITECONF_FILE"
    echo "CVMFS 마운트 상태를 확인하세요."
fi
echo "=========================="

# SITECONF 문제 해결을 위한 환경변수 설정
# 방법 1: 안정적인 T2 사이트 사용
export CMS_LOCAL_SITE=T2_US_Purdue
export SITECONFIG_PATH=/cvmfs/cms.cern.ch/SITECONF/T2_US_Purdue

# 방법 2: 파일 카탈로그 완전 비활성화 (더 확실한 방법)
export CMS_DISABLE_TRIVIAL_FILE_CATALOG=1
export CMS_SKIP_SITE_LOCAL_CONFIG=1

# 방법 3: 입력 파일을 직접 지정 (카탈로그 우회)
export CMSSW_USE_DIRECT_IO=1

echo "=== CMS 환경변수 설정 ==="
echo "CMS_LOCAL_SITE: $CMS_LOCAL_SITE"
echo "SITECONFIG_PATH: $SITECONFIG_PATH"
echo "CMS_DISABLE_TRIVIAL_FILE_CATALOG: $CMS_DISABLE_TRIVIAL_FILE_CATALOG"
echo "CMS_SKIP_SITE_LOCAL_CONFIG: $CMS_SKIP_SITE_LOCAL_CONFIG"
echo "CMSSW_USE_DIRECT_IO: $CMSSW_USE_DIRECT_IO"
echo "=========================="


cmsenv 



cmsDriver.py Phase2 -s L1,L1TrackTrigger \
--conditions auto:phase2_realistic_T33 \
--geometry ExtendedRun4D110 \
--era Phase2C17I13M9 \
--eventcontent FEVTDEBUGHLT \
--datatier GEN-SIM-DIGI-RAW-MINIAOD \
--customise SLHCUpgradeSimulations/Configuration/aging.customise_aging_1000,Configuration/DataProcessing/Utils.addMonitoring,L1Trigger/Configuration/customisePhase2FEVTDEBUGHLT.customisePhase2FEVTDEBUGHLT,L1Trigger/Configuration/customisePhase2TTOn110.customisePhase2TTOn110 \
--filein file:$MYFILE \
--fileout file:/gv0/Users/achihwan/phase2/cmssw_16/condor/rerunL1/output_Phase2_L1T_$(basename "$MYFILE") \
--python_filename rerunL1_cfg_$(basename "$MYFILE").py \
--inputCommands="keep *, drop l1tPFJets_*_*_*, drop l1tTrackerMuons_l1tTkMuonsGmt*_*_HLT" \
--outputCommands="drop l1tTrackerMuons_l1tTkMuonsGmt*_*_HLT" \
--mc \
-n 1000 --nThreads 5

#chmod +x rerunL1_cfg_$(basename "$MYFILE").py
#cmsRun rerunL1_cfg_$(basename "$MYFILE").py

echo "setup1 done"

cmsDriver.py step2 --processName=HLTX \
-s L1P2GT,HLT:@relvalRun4,NANO:@Phase2HLT \
--conditions auto:phase2_realistic_T33 \
--datatier GEN-SIM-DIGI-RAW,NANOAODSIM \
--eventcontent FEVTDEBUGHLT,NANOAODSIM \
--python_filename step2_L1P2GT_HLT_NANO_$(basename "$MYFILE").py \
--geometry ExtendedRun4D110 --era Phase2C17I13M9 \
--inputCommands='keep *, drop *_hlt*_*_HLT, drop triggerTriggerFilterObjectWithRefs_l1t*_*_HLT' \
--filein file:/gv0/Users/achihwan/phase2/cmssw_16/condor/rerunL1/output_Phase2_L1T_$(basename "$MYFILE") -n 1000 --fileout file:/gv0/Users/achihwan/phase2/cmssw_16/condor/nanoaod/step2_$(basename "$MYFILE") \
--nThreads 5

chmod +x step2_L1P2GT_HLT_NANO_$(basename "$MYFILE").py

# wantSummary를 True로 변경
sed -i 's/wantSummary = cms.untracked.bool(False)/wantSummary = cms.untracked.bool(True)/g' step2_L1P2GT_HLT_NANO_$(basename "$MYFILE").py

# wantSummary 블록 뒤에 코드 추가
sed -i '/wantSummary = cms.untracked.bool(True)/,/^)/{
    /^)/a\
\
process.tauGenJetsForNano = cms.EDProducer(\
    "TauGenJetProducer",\
    GenParticles = cms.InputTag("genParticles"),\
    includeNeutrinos = cms.bool(False),\
    verbose = cms.untracked.bool(False)\
)\
\
process.tauGenJetsSelectorAllHadronsForNano = cms.EDFilter(\
    "TauGenJetDecayModeSelector",\
    src = cms.InputTag("tauGenJetsForNano"),\
    select = cms.vstring(\
        "oneProng0Pi0",\
        "oneProng1Pi0",\
        "oneProng2Pi0",\
        "oneProngOther",\
        "threeProng0Pi0",\
        "threeProng1Pi0",\
        "threeProngOther",\
        "rare"\
    ),\
    filter = cms.bool(False)\
)\
\
process.genVisTaus = cms.EDProducer(\
    "GenVisTauProducer",\
    src = cms.InputTag("tauGenJetsSelectorAllHadronsForNano"),\
    srcGenParticles = cms.InputTag("genParticles")\
)\
\
process.SimTauProducer = cms.EDProducer(\
    "SimTauProducer",\
    caloParticles = cms.InputTag("mix", "MergedCaloTruth"),\
    genBarcodes = cms.InputTag("genParticles"),\
    genParticles = cms.InputTag("genParticles")\
)
}' step2_L1P2GT_HLT_NANO_$(basename "$MYFILE").py

sed -i '/process\.NANOAODSIMoutput_step = cms\.EndPath(process\.NANOAODSIMoutput)/r /dev/stdin' step2_L1P2GT_HLT_NANO_$(basename "$MYFILE").py << 'EOF'

# Custom tau analysis paths
process.p = cms.Path(process.tauGenJetsForNano+process.tauGenJetsSelectorAllHadronsForNano+process.genVisTaus)
process.simTaus = cms.Path(process.SimTauProducer)

EOF

# schedule.extend 라인을 찾아서 대체
sed -i 's/process\.schedule\.extend(\[process\.nanoAOD_step,process\.endjob_step,process\.FEVTDEBUGHLToutput_step,process\.NANOAODSIMoutput_step\])/process.schedule.extend([process.nanoAOD_step,process.endjob_step,process.FEVTDEBUGHLToutput_step,process.NANOAODSIMoutput_step,process.p,process.simTaus])/' step2_L1P2GT_HLT_NANO_$(basename "$MYFILE").py

cmsRun step2_L1P2GT_HLT_NANO_$(basename "$MYFILE").py &> hlt_test_$(basename "$MYFILE").log

# 특정 TrigReport 라인들을 추출하여 txt 파일로 저장
echo "=== TrigReport 결과 추출 중 ==="
OUTPUT_FILE="trigReport_$(basename "$MYFILE" .root).txt"

# 세 개의 특정 라인 추출
grep "HLT_LooseDeepTauPFTauHPS180_L2NN_eta2p1" hlt_test_$(basename "$MYFILE").log > "$OUTPUT_FILE"
grep "hltL1SingleNNTau150" hlt_test_$(basename "$MYFILE").log >> "$OUTPUT_FILE"
grep "hltHpsPFTau180LooseTauWPDeepTau" hlt_test_$(basename "$MYFILE").log >> "$OUTPUT_FILE"

echo "TrigReport 결과가 $OUTPUT_FILE 에 저장되었습니다."
echo "--- 추출된 내용 ---"
cat "$OUTPUT_FILE"
echo "--- 추출 완료 ---"

cd /gv0/Users/achihwan/phase2/cmssw_16/condor/nanoaod 
mv *SIM.root ../hltrun
#cd /gv0/Users/achihwan/phase2/cmssw_16/condor/hltrun
#hadd step2_nanoaod.root step2_*SIM.root

#cd /data6/Users/achihwan/CMSSW_15_1_0_pre4/src/PhysicsTools/NanoAOD/scripts
#python3 inspectNanoFile.py -d /data6/Users/achihwan/CMSSW_15_1_0_pre4/src/EventContent.html -s /data6/Users/achihwan/CMSSW_15_1_0_pre4/src/SizeReport.html /gv0/Users/achihwan/phase2cmssw_16cmssw_16/condor/hltrun/step2_nanoaod.root
