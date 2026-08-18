import SwiftUI

/// Root screen, mirrors MainForm.cs's BuildInterface(): logo, quick voucher
/// grid, last-voucher card, status row, settings entry point.
struct MainView: View {
    @StateObject private var viewModel = MainViewModel()

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                VStack(alignment: .leading, spacing: 4) {
                    Text("QUICK VOUCHERS")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Text("Select a duration to create and print a voucher instantly.")
                        .font(.system(size: 13))
                        .foregroundColor(PixlTheme.muted)
                }

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(VoucherDuration.all) { duration in
                        VoucherButton(duration: duration, isDisabled: viewModel.isBusy) {
                            viewModel.createVoucher(duration)
                        }
                    }
                }

                LastVoucherCard(code: viewModel.lastVoucherCode) {
                    viewModel.reprintLastVoucher()
                }

                HStack(spacing: 20) {
                    StatusPill(label: "MikroTik", status: viewModel.mikrotikStatus)
                    StatusPill(label: "Printer", status: viewModel.printerStatus)
                }
            }
            .padding(20)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(PixlTheme.background.ignoresSafeArea())
        .overlay {
            if viewModel.isBusy {
                ProgressView()
                    .tint(.white)
                    .padding(20)
                    .background(PixlTheme.panel, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .sheet(isPresented: $viewModel.showSettings) {
            SettingsView {
                Task { await viewModel.refreshStatuses() }
            }
        }
        .alert(item: $viewModel.alert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
        }
        .onAppear { viewModel.onAppear() }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Image("PixlLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 60)
                Text("WI-FI VOUCHERS")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(PixlTheme.muted)
            }

            Spacer()

            Button {
                viewModel.showSettings = true
            } label: {
                Text("SETTINGS")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(PixlTheme.border, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    MainView()
}
