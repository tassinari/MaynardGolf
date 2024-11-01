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
                    Section("About"){
                        VStack(alignment: .leading){
                            Text("Maynard Golf")
                                .font(.headline)
                                .padding([.bottom],5)
                            Text("Version 1.0")
                                .font(.caption)
                                .foregroundStyle(.gray)
                            Text("by Mark Tassinari")
                                .font(.caption)
                                .foregroundStyle(.gray)
                            
                            Text("Maynard golf is a free and open source software project and not associated with Maynard Golf Club.")
                                .font(.caption)
                                .foregroundStyle(.gray)
                                .padding(.top, 10)
                            
                            
                            Text("View on GitHub:")
                                .font(.caption)
                                .foregroundStyle(.gray)
                                .padding(.top)
                            Text("https://github.com/tassinari/MaynardGolf")
                                .font(.caption)

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
