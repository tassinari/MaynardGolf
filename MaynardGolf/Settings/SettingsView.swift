//
//  SettingsView.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 10/13/24.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State var importing: Bool = false
    var body: some View {
        NavigationStack{
            VStack{
                List(){
                    Section("Export") {
                        ShareLink(item: Round.exportData()) {
                            Text("Export")
                        }
                        Button("Import") {
                            importing = true
                        }
                        .fileImporter(
                                   isPresented: $importing,
                                   allowedContentTypes: [.plainText]
                               ) { result in
                                   switch result {
                                   case .success(let file):
                                       Round.importData(file: file)
                                   case .failure(let error):
                                       print(error.localizedDescription)
                                   }
                               }
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        presentationMode.wrappedValue.dismiss()
                        
                    } label: {
                        Text("Done")
                    }
                }
            }
            
        }
       
    }
}

#Preview {
    SettingsView()
}
