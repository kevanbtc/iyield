import { ethers } from "hardhat";
import { IPFS } from "ipfs-core";
import * as fs from "fs";
import * as path from "path";

/**
 * @title IPFS Disclosure Pinning Script
 * @dev Script to pin disclosure documents to IPFS and update on-chain CID
 * @notice This script handles the full disclosure lifecycle for iYield Protocol
 */

interface DisclosureMetadata {
  version: string;
  title: string;
  description: string;
  created: string;
  lastModified: string;
  author: string;
  hash: string;
  previousHash?: string;
}

interface IPFSPinResult {
  hash: string;
  size: number;
  pinned: boolean;
}

class DisclosurePinner {
  private ipfs: any;
  private contract: any;
  private signer: any;

  constructor() {
    // IPFS configuration
    this.initializeIPFS();
  }

  /**
   * Initialize IPFS node
   */
  private async initializeIPFS(): Promise<void> {
    try {
      this.ipfs = await IPFS.create({
        repo: './ipfs-repo',
        config: {
          Addresses: {
            Swarm: [
              '/ip4/0.0.0.0/tcp/4001',
              '/ip4/127.0.0.1/tcp/4001/ws'
            ]
          },
          Discovery: {
            MDNS: {
              Enabled: true,
              Interval: 10
            },
            webRTCStar: {
              Enabled: true
            }
          }
        }
      });
      console.log('IPFS node initialized');
    } catch (error) {
      console.error('Failed to initialize IPFS:', error);
      throw error;
    }
  }

  /**
   * Connect to smart contract
   */
  async connectContract(contractAddress: string): Promise<void> {
    try {
      const [signer] = await ethers.getSigners();
      this.signer = signer;

      // Get contract ABI (assuming it's compiled)
      const ContractFactory = await ethers.getContractFactory("ERCRWACSV");
      this.contract = ContractFactory.attach(contractAddress);
      
      console.log(`Connected to contract at ${contractAddress}`);
    } catch (error) {
      console.error('Failed to connect to contract:', error);
      throw error;
    }
  }

  /**
   * Create disclosure document with metadata
   */
  async createDisclosureDocument(
    templatePath: string,
    metadata: Partial<DisclosureMetadata>
  ): Promise<{ content: string; metadata: DisclosureMetadata }> {
    try {
      // Read template file
      const templateContent = fs.readFileSync(templatePath, 'utf8');
      
      // Get current disclosure hash from contract (if exists)
      let previousHash: string | undefined;
      try {
        previousHash = await this.contract.getDisclosureHash();
        if (previousHash === '') previousHash = undefined;
      } catch (error) {
        console.log('No previous disclosure hash found');
      }

      // Create full metadata
      const fullMetadata: DisclosureMetadata = {
        version: metadata.version || "1.0",
        title: metadata.title || "iYield Protocol Regulatory Disclosure",
        description: metadata.description || "Regulatory disclosure for insurance CSV backed tokens",
        created: metadata.created || new Date().toISOString(),
        lastModified: new Date().toISOString(),
        author: metadata.author || "iYield Protocol Team",
        hash: "", // Will be filled after IPFS upload
        ...(previousHash && { previousHash })
      };

      // Replace placeholders in template
      let content = templateContent;
      content = content.replace(/\[Date\]/g, new Date().toLocaleDateString());
      content = content.replace(/\[Version\]/g, fullMetadata.version);
      content = content.replace(/\[Last Updated\]/g, fullMetadata.lastModified);

      // Add metadata header
      const metadataHeader = `---
Version: ${fullMetadata.version}
Title: ${fullMetadata.title}
Created: ${fullMetadata.created}
Last Modified: ${fullMetadata.lastModified}
Author: ${fullMetadata.author}
${previousHash ? `Previous Hash: ${previousHash}` : ''}
---

`;

      content = metadataHeader + content;

      return { content, metadata: fullMetadata };
    } catch (error) {
      console.error('Failed to create disclosure document:', error);
      throw error;
    }
  }

  /**
   * Pin content to IPFS
   */
  async pinToIPFS(content: string): Promise<IPFSPinResult> {
    try {
      console.log('Pinning content to IPFS...');
      
      // Add content to IPFS
      const result = await this.ipfs.add({
        content: Buffer.from(content, 'utf8')
      });

      // Pin the content
      await this.ipfs.pin.add(result.cid);

      const pinResult: IPFSPinResult = {
        hash: result.cid.toString(),
        size: result.size,
        pinned: true
      };

      console.log(`Content pinned to IPFS with hash: ${pinResult.hash}`);
      return pinResult;
    } catch (error) {
      console.error('Failed to pin to IPFS:', error);
      throw error;
    }
  }

  /**
   * Update on-chain CID
   */
  async updateOnChainCID(ipfsHash: string): Promise<string> {
    try {
      console.log(`Updating on-chain CID to: ${ipfsHash}`);

      // Check if caller has permission
      const hasRole = await this.contract.hasRole(
        await this.contract.DEFAULT_ADMIN_ROLE(),
        this.signer.address
      );

      if (!hasRole) {
        throw new Error('Signer does not have permission to update disclosure hash');
      }

      // Update disclosure hash on-chain
      const tx = await this.contract.updateDisclosureHash(ipfsHash);
      await tx.wait();

      console.log(`Disclosure hash updated on-chain. Transaction: ${tx.hash}`);
      return tx.hash;
    } catch (error) {
      console.error('Failed to update on-chain CID:', error);
      throw error;
    }
  }

  /**
   * Verify IPFS content
   */
  async verifyIPFSContent(ipfsHash: string, expectedContent: string): Promise<boolean> {
    try {
      console.log(`Verifying content for IPFS hash: ${ipfsHash}`);

      // Retrieve content from IPFS
      const chunks = [];
      for await (const chunk of this.ipfs.cat(ipfsHash)) {
        chunks.push(chunk);
      }
      const retrievedContent = Buffer.concat(chunks).toString('utf8');

      // Compare content
      const isValid = retrievedContent === expectedContent;
      console.log(`Content verification: ${isValid ? 'PASSED' : 'FAILED'}`);

      return isValid;
    } catch (error) {
      console.error('Failed to verify IPFS content:', error);
      return false;
    }
  }

  /**
   * Get disclosure history
   */
  async getDisclosureHistory(): Promise<any[]> {
    try {
      // This would query blockchain events for disclosure updates
      const filter = this.contract.filters.DisclosureUpdated();
      const events = await this.contract.queryFilter(filter);

      const history = events.map(event => ({
        hash: event.args?.ipfsHash,
        blockNumber: event.blockNumber,
        transactionHash: event.transactionHash,
        timestamp: event.args?.timestamp
      }));

      return history;
    } catch (error) {
      console.error('Failed to get disclosure history:', error);
      return [];
    }
  }

  /**
   * Save disclosure to local file system
   */
  private saveDisclosureLocally(
    content: string,
    metadata: DisclosureMetadata,
    outputDir: string = './disclosures'
  ): string {
    try {
      // Create output directory if it doesn't exist
      if (!fs.existsSync(outputDir)) {
        fs.mkdirSync(outputDir, { recursive: true });
      }

      // Create filename with timestamp
      const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
      const filename = `disclosure-${metadata.version}-${timestamp}.md`;
      const filepath = path.join(outputDir, filename);

      // Save content
      fs.writeFileSync(filepath, content);

      // Save metadata
      const metadataPath = path.join(outputDir, `${filename}.meta.json`);
      fs.writeFileSync(metadataPath, JSON.stringify(metadata, null, 2));

      console.log(`Disclosure saved locally: ${filepath}`);
      return filepath;
    } catch (error) {
      console.error('Failed to save disclosure locally:', error);
      throw error;
    }
  }

  /**
   * Main function to pin disclosure and update contract
   */
  async pinDisclosure(options: {
    contractAddress: string;
    templatePath: string;
    metadata?: Partial<DisclosureMetadata>;
    verify?: boolean;
    saveLocally?: boolean;
  }): Promise<{
    ipfsHash: string;
    transactionHash: string;
    content: string;
    metadata: DisclosureMetadata;
    localPath?: string;
  }> {
    try {
      console.log('Starting disclosure pinning process...');

      // Connect to contract
      await this.connectContract(options.contractAddress);

      // Create disclosure document
      const { content, metadata } = await this.createDisclosureDocument(
        options.templatePath,
        options.metadata || {}
      );

      // Pin to IPFS
      const pinResult = await this.pinToIPFS(content);

      // Update metadata with IPFS hash
      metadata.hash = pinResult.hash;

      // Update on-chain CID
      const transactionHash = await this.updateOnChainCID(pinResult.hash);

      // Verify content if requested
      if (options.verify) {
        const isValid = await this.verifyIPFSContent(pinResult.hash, content);
        if (!isValid) {
          throw new Error('IPFS content verification failed');
        }
      }

      // Save locally if requested
      let localPath: string | undefined;
      if (options.saveLocally) {
        localPath = this.saveDisclosureLocally(content, metadata);
      }

      console.log('Disclosure pinning completed successfully!');

      return {
        ipfsHash: pinResult.hash,
        transactionHash,
        content,
        metadata,
        ...(localPath && { localPath })
      };
    } catch (error) {
      console.error('Disclosure pinning failed:', error);
      throw error;
    }
  }

  /**
   * Close IPFS connection
   */
  async close(): Promise<void> {
    if (this.ipfs) {
      await this.ipfs.stop();
      console.log('IPFS node stopped');
    }
  }
}

// CLI interface
async function main() {
  const args = process.argv.slice(2);
  
  if (args.length < 2) {
    console.error('Usage: npx ts-node scripts/pin-disclosure.ts <contract-address> <template-path> [options]');
    console.error('Options:');
    console.error('  --version <version>     Disclosure version (default: 1.0)');
    console.error('  --title <title>         Disclosure title');
    console.error('  --verify                Verify IPFS content after pinning');
    console.error('  --save-locally          Save disclosure to local filesystem');
    console.error('  --history               Show disclosure history');
    process.exit(1);
  }

  const contractAddress = args[0];
  const templatePath = args[1];
  
  // Parse options
  const options = {
    contractAddress,
    templatePath,
    metadata: {} as Partial<DisclosureMetadata>,
    verify: args.includes('--verify'),
    saveLocally: args.includes('--save-locally')
  };

  // Parse version
  const versionIndex = args.indexOf('--version');
  if (versionIndex !== -1 && args[versionIndex + 1]) {
    options.metadata.version = args[versionIndex + 1];
  }

  // Parse title
  const titleIndex = args.indexOf('--title');
  if (titleIndex !== -1 && args[titleIndex + 1]) {
    options.metadata.title = args[titleIndex + 1];
  }

  const pinner = new DisclosurePinner();

  try {
    if (args.includes('--history')) {
      // Show disclosure history
      await pinner.connectContract(contractAddress);
      const history = await pinner.getDisclosureHistory();
      console.log('Disclosure History:');
      console.table(history);
    } else {
      // Pin new disclosure
      const result = await pinner.pinDisclosure(options);
      
      console.log('\n=== Disclosure Pinning Results ===');
      console.log(`IPFS Hash: ${result.ipfsHash}`);
      console.log(`Transaction Hash: ${result.transactionHash}`);
      console.log(`Version: ${result.metadata.version}`);
      if (result.localPath) {
        console.log(`Local Path: ${result.localPath}`);
      }
      console.log('\nDisclosure successfully pinned and updated on-chain!');
    }
  } catch (error) {
    console.error('Script failed:', error);
    process.exit(1);
  } finally {
    await pinner.close();
  }
}

// Export for use as module
export { DisclosurePinner, DisclosureMetadata, IPFSPinResult };

// Run as CLI if called directly
if (require.main === module) {
  main().catch(console.error);
}