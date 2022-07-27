//
//  EvaluationView.swift
//  HumanCorporation
//
//  Created by 서현종 on 2022/07/19.
//
/*
 실적을 제출하거나 다시 작성 버튼을 누르면 다이어리 리스트, 가격 리스트가 초기화 되어야 한다.
 다른 날짜를 선택할 때에도 다이어리, 가격 리스트가 초기화 되어야 한다.
 **참고: Swift의 Array는 구조체로 구현되어 있어 값타입 -> 복사할때 서로 영향 X
 그러나 요소에 값 타입이 아닌 참조 타입이 들어간 경우 복사할 때 영향이 있다고 한다.
 이미 오늘 날짜까지 일정을 추가한 경우 (viewModel >= Date()) "추가할 실적이 없네요..." 라는 뷰가 떠야 한다.
 */
//24hr == 86400
//1 min == 0.04%
import SwiftUI
import AlertToast
import Charts

struct EvaluationView: View {
    @State private var showCalendar = false
    @State private var date = Date()
    @State private var strDate = "2022.07.22.Fri"
    @State private var startTime = Date()
    @State private var endTime = Date()
    @State private var pickStart = Date()
    
    @State private var story = "일과를 작성해주세요."
    @State private var eval = Diary.Evaluation.cancel
    
    @State private var showToast = false
    @State private var showError = false
    @State private var errorMsg = ""
    @State private var showSuccess = false
    @State private var showDiary = false
    @State private var showAlert = false
    
    @EnvironmentObject var viewModel: ViewModel
    @State private var diaryList:[Diary] = []
    @State private var previousClose: Double = 1000
    @State private var currentPrice: Double = 1000
    @State private var priceList:[Double] = []
    
    var body: some View {
        NavigationView{
            VStack(alignment: .center) {
                Form{
                    Section("그날의 자정부터 순서대로 기록해주세요.") {
                        DatePicker("시작 시간", selection: $startTime, in: pickStart...pickStart)
                        DatePicker("종료 시간", selection: $endTime, in: pickStart...Date())
                        HStack {
                            Label(String(format: "%.0f", endTime.timeIntervalSince(startTime) / 60)+" min", systemImage: "clock")
                            Spacer()
                            Button {
                                if endTime.timeIntervalSince(startTime) > 0 {
                                    eval = .cancel
                                    showDiary.toggle()
                                }  else {
                                    errorMsg = "시간 설정 오류"
                                    showError.toggle()
                                }
                            } label: {
                                Label("실적 추가", systemImage: "plus.circle.fill")
                            }.buttonStyle(BorderlessButtonStyle())
                        }
                    }
                    Section("현재 가격") {
                        Label(String(format: "%.0f", currentPrice), systemImage: "dollarsign.circle.fill")
                    }
                }
                HStack() {
                    Button{
                        if priceList.count > 0 {
                            showAlert.toggle()
                        } else {
                            errorMsg = "추가된 실적이 없음"
                            showError.toggle()
                        }
                    } label: {
                        Text("실적 최종 제출")
                            .foregroundColor(Color.white)
                            .padding(.vertical,10)
                            .padding(.horizontal,15)
                            .background(Color.blue)
                            .cornerRadius(45)
                    }
                    Button{
                        
                    } label: {
                        Text("다시 작성하기")
                            .foregroundColor(Color.white)
                            .padding(.vertical,10)
                            .padding(.horizontal,15)
                            .background(Color.red)
                            .cornerRadius(45)
                    }
                }
                Spacer()
            }
            .navigationTitle(strDate)
            .toolbar{
                Label("select date", systemImage: "calendar")
                    .onTapGesture {
                        showCalendar.toggle()
                    }
            }
        }
        .onAppear(){
            updateSelectedDate()
            if viewModel.priceList.isEmpty == false {
                viewModel.findRecentDay()
                previousClose = viewModel.priceList.last!.close
                currentPrice = previousClose
            }
        }
        .alert("정말 제출하실건가요? 한 번 제출되면 그 날의 일과는 수정이 불가능합니다!", isPresented: $showAlert) {
            Button("제출") {
                //값 타입으로 전달하여 리스트가 초기화 될 때 비동기 처리에서 문제가 안생기게 하여야...
                let valDiaryList = diaryList
                viewModel.diaryAdd(diaryList: valDiaryList)
                
                let valPriceList = priceList
                let price = CandleChartDataEntry(x: 0, shadowH: valPriceList.max()!, shadowL: valPriceList.min()!, open: valPriceList.first!, close: valPriceList.last!)
                viewModel.priceAdd(price: price)
                
                viewModel.findRecentDay()
                date = date.addingTimeInterval(86400) //자동으로 다음날 일과 추가할 수 있게
                updateSelectedDate()
                showSuccess.toggle()
            }
            Button("취소", role: .cancel) {
            }
        }
        .sheet(isPresented: $showCalendar, onDismiss: updateSelectedDate){
            DatePicker("날짜를 고르세요.", selection: $date, in: viewModel.recentDay...Date(), displayedComponents: [.date])
                .datePickerStyle(.graphical)
        }
        .sheet(isPresented: $showDiary, onDismiss: addDiary) {
            DiaryFieldView(story: $story, eval: $eval, showDiary: $showDiary)
        }
        .toast(isPresenting: $showToast) {
            AlertToast(displayMode: .banner(.slide), type: .regular, title:"실적 추가 성공!")
        }
        .toast(isPresenting: $showError) {
            AlertToast(displayMode: .alert, type: .error(.red), title: errorMsg)
        }
        .toast(isPresenting: $showSuccess) {
            AlertToast(displayMode: .alert, type: .complete(.green), title: "실적 제출 성공!")
        }
    }
    /*
     날짜 선택시 네비게이션 타이틀 바를 업데이트하고,
     해당 날짜의 자정부터 시간을 선택할 수 있게 시간 세팅
     또한 다이어리, 가격 리스트 초기화
     */
    func updateSelectedDate(){
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "YYYY.MM.dd.E"
        strDate = dateFormatter.string(from: date)
        
        startTime = Calendar.current.startOfDay(for: date)
        endTime = Calendar.current.startOfDay(for: date)
        pickStart = Calendar.current.startOfDay(for: date)
        
        diaryList.removeAll()
        priceList.removeAll()
    }
    func addDiary() {
        let time = endTime.timeIntervalSince(startTime) / 60
        let variance = previousClose * (time * 0.04) * 0.01
        
        switch eval {
        case .productive:
            currentPrice += variance
        case .unproductive:
            currentPrice -= variance
        case .neutral: break
        case .cancel:
            return
        }
        
        let diary = Diary(story: story, startTime: startTime, endTime: endTime, eval: eval)
        self.priceList.append(currentPrice)
        self.diaryList.append(diary)
        pickStart = endTime
        startTime = endTime
        showToast.toggle()
        story = "일과를 작성해주세요."
    }
}

struct EvaluationView_Previews: PreviewProvider {
    static var previews: some View {
        EvaluationView()
            .environmentObject(ViewModel())
    }
}
