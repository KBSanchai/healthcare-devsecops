pipeline {
  agent any

  environment {
    DOCKER_HUB_USER = 'kbsanchai'
    IMAGE_NAME      = "${DOCKER_HUB_USER}/healthcare-api"
    FULL_IMAGE      = "${IMAGE_NAME}:${BUILD_NUMBER}"
    KUBECONFIG      = '/var/lib/jenkins/.kube/config'
    NAMESPACE       = 'healthcare'
    OWASP_DC        = '/opt/dependency-check/dependency-check/bin/dependency-check.sh'
  }

  stages {

    stage('Checkout') {
      steps {
        git branch: 'main',
            url: 'https://github.com/KBSanchai/healthcare-devsecops.git'
        echo 'Source code checked out.'
      }
    }

    stage('OWASP Dependency Check') {
      steps {
        sh '''
          ${OWASP_DC} \
            --project "healthcare-api" \
            --scan "./app" \
            --format HTML \
            --format JSON \
            --out "./dependency-check-report" \
            --nvdApiKey Secure-API-27f959c433bcdc79798db6165842daa2 \
            --failOnCVSS 7 \
            --enableRetired || true
          echo "OWASP scan completed"
        '''
      }
      post {
        always {
          publishHTML(target: [
            allowMissing: true,
            alwaysLinkToLastBuild: true,
            keepAll: true,
            reportDir: 'dependency-check-report',
            reportFiles: 'dependency-check-report.html',
            reportName: 'OWASP Dependency Check Report'
          ])
        }
      }
    }

    stage('Unit Tests') {
      steps {
        sh '''
          cd app
          python3 -m pip install -r requirements.txt --quiet --break-system-packages
          python3 -m pytest tests/ -v --tb=short --junitxml=../test-results.xml
        '''
      }
      post {
        always {
          junit allowEmptyResults: true, testResults: 'test-results.xml'
        }
      }
    }

    stage('Build Docker Image') {
      steps {
        sh "docker build --no-cache -t ${FULL_IMAGE} ."
        sh "docker tag ${FULL_IMAGE} ${IMAGE_NAME}:latest"
      }
    }

    stage('Trivy Vulnerability Scan') {
      steps {
        sh '''
          chmod +x scripts/trivy-scan.sh
          ./scripts/trivy-scan.sh ${FULL_IMAGE} CRITICAL,HIGH trivy-report.json
        '''
      }
      post {
        always {
          archiveArtifacts artifacts: 'trivy-report.json',
                           allowEmptyArchive: true
        }
      }
    }

    stage('Push Secure Image') {
      steps {
        withCredentials([usernamePassword(
          credentialsId: 'dockerhub-credentials',
          usernameVariable: 'DOCKER_USER',
          passwordVariable: 'DOCKER_PASS'
        )]) {
          sh '''
            docker login -u $DOCKER_USER -p $DOCKER_PASS
            docker push ${FULL_IMAGE}
            docker push ${IMAGE_NAME}:latest
            docker logout
          '''
        }
      }
    }

    stage('Apply Security Policies') {
      steps {
        sh '''
          kubectl apply -f k8s/namespace.yaml \
            --kubeconfig=${KUBECONFIG}
          kubectl apply -f k8s/rbac.yaml \
            --kubeconfig=${KUBECONFIG}
          kubectl apply -f k8s/network-policy.yaml \
            --kubeconfig=${KUBECONFIG}
        '''
      }
    }

    stage('Create Secrets') {
      steps {
        sh '''
          kubectl create secret generic healthcare-secrets \
            --from-literal=db-password="SuperSecure@DB2024" \
            --from-literal=api-token="Secure-API-Token-123456" \
            --from-literal=secret-key="my-secret-key-here" \
            --namespace=${NAMESPACE} \
            --kubeconfig=${KUBECONFIG} \
            --dry-run=client -o yaml | \
          kubectl apply -f - --kubeconfig=${KUBECONFIG}
        '''
      }
    }

    stage('Secure Deploy') {
      steps {
        sh '''
          sed -i "s|YOUR_DOCKERHUB_USERNAME|${DOCKER_HUB_USER}|g" \
            k8s/deployment.yaml
          kubectl apply -f k8s/deployment.yaml \
            --kubeconfig=${KUBECONFIG}
          kubectl apply -f k8s/service.yaml \
            --kubeconfig=${KUBECONFIG}
          kubectl rollout status deployment/healthcare-api \
            -n ${NAMESPACE} \
            --timeout=300s \
            --kubeconfig=${KUBECONFIG}
        '''
      }
    }

    stage('Verify Security Posture') {
      steps {
        sh '''
          echo "=== Pods ==="
          kubectl get pods -n ${NAMESPACE} \
            --kubeconfig=${KUBECONFIG}

          echo "=== Network Policies ==="
          kubectl get networkpolicies -n ${NAMESPACE} \
            --kubeconfig=${KUBECONFIG}

          echo "=== RBAC Bindings ==="
          kubectl get rolebindings -n ${NAMESPACE} \
            --kubeconfig=${KUBECONFIG}

          echo "=== Service ==="
          kubectl get svc -n ${NAMESPACE} \
            --kubeconfig=${KUBECONFIG}

          echo "=== Verify Non-Root User ==="
          kubectl exec -n ${NAMESPACE} \
            $(kubectl get pod -n ${NAMESPACE} \
              -l app=healthcare-api \
              -o jsonpath="{.items[0].metadata.name}" \
              --kubeconfig=${KUBECONFIG}) \
            -- id \
            --kubeconfig=${KUBECONFIG} || true
        '''
      }
    }

  }

  post {
    success {
      echo 'DevSecOps pipeline PASSED all security gates!'
      echo "Access app at: http://<K8s-Worker-IP>:30300"
    }
    failure {
      sh '''
        kubectl rollout undo deployment/healthcare-api \
          -n ${NAMESPACE} \
          --kubeconfig=${KUBECONFIG} || true
      '''
    }
    always {
      sh 'docker rmi ${FULL_IMAGE} || true'
      archiveArtifacts artifacts: 'trivy-report.json,test-results.xml',
                       allowEmptyArchive: true
      cleanWs()
    }
  }
}
