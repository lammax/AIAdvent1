//
//  AnimatedDropdownMenuView.swift
//  AIChallenge
//
//  Created by Максим Ламанский on 22.03.26.
//
// https://medium.com/@wesleymatlock/creating-advanced-dropdown-menus-in-swiftui-74fd20cf9bab

import SwiftUI

struct AnimatedDropdownMenu: View {
    @Namespace private var animationNamespace

    let options: [PromptTemplate]
    @Binding var selectedOption: PromptTemplate?

    @State private var isExpanded = false

    var body: some View {
    VStack {
        Button(action: {
            withAnimation(.spring()) {
              isExpanded.toggle()
            }
        }) {
            HStack {
                Text(selectedOption?.title ?? "Select a prompt")
              Spacer()
              Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
            .matchedGeometryEffect(id: "dropup", in: animationNamespace)
        }

        if isExpanded {
            VStack {
              ForEach(options, id: \.self) { option in
                  Text(option.title)
                  .padding()
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .background(Color.white)
                  .onTapGesture {
                    withAnimation(.spring()) {
                      selectedOption = option
                      isExpanded = false
                    }
                  }
                  .matchedGeometryEffect(id: "dropup-\(option)", in: animationNamespace)
              }
            }
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .transition(.scale)
        }
    }
    .padding()
    }
}
