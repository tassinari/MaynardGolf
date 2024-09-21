//
//  PlayerEntryView.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 9/13/24.
//

import SwiftUI
import SwiftData

extension PlayerEntryView{
    
    enum PlayerEntryError : Error{
        case userExsists
    }
    
    struct ViewModel{
        private var _text : String = ""
        var firstName : String = ""
        var lastName : String = ""
        var exsistsError : Bool = false
        
        func nameExsists(first: String,last : String, context : ModelContext) throws -> Bool{
            
            let predicate = #Predicate<Player> { p in
                p.firstName.localizedStandardContains(first) && p.lastName.localizedStandardContains(last)
            }
            return try context.fetch(FetchDescriptor<Player>(predicate: predicate)).count != 0
            
        }
        
        func addUser( context : ModelContext) throws{
            if firstName.isEmpty || lastName.isEmpty { return }
            if  try nameExsists(first: firstName, last: lastName, context: context){
                throw PlayerEntryError.userExsists
            }
            do{
                
                let player = Player(firstName: firstName, lastName: lastName)
                context.insert(player)
                
                try context.save()
            }catch let e{
                print(String(describing: e))
            }
        }
        var shouldDenyEntry : Bool{
            
            
            return firstName.isEmpty || lastName.isEmpty
            
        }
        
    }
}

struct PlayerEntryView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.modelContext) private var context
    @Query var players: [Player]
    @State var model : ViewModel = ViewModel()
    var body: some View {
        VStack{
            Text("New Player")
            
            TextField("First Name", text: $model.firstName)
                .padding([.leading,.trailing, .top])
            TextField("Last Name", text: $model.lastName)
                .padding([.leading,.trailing, .top])
            if(model.exsistsError){
                Text("Already Exsists").font(.callout).foregroundStyle(.red)
            }
            
            HStack {
                
                
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }, label: {
                    Text("Cancel")
                })
                .padding()
                Spacer()
                Button(action: {
                    do{
                        try model.addUser( context: context)
                    }catch PlayerEntryError.userExsists{
                        model.exsistsError = true
                        return
                    }
                    catch{
                        print("error")
                    }
                    
                    presentationMode.wrappedValue.dismiss()
                }, label: {
                    Text("Create")
                })
                .padding()
                .disabled(model.shouldDenyEntry)
            }
            Spacer()
        }
        .padding()
    }
}

#Preview {
    PlayerEntryView()
}
